import Swift

/// Tracking-only owner of permanent and plan-scoped memory capacity.
public final class Arena {
    public typealias Diagnostics = (String) -> Void

    public let permanentPlan: MemoryPlan?
    public let plans: [MemoryPlan]
    public let concurrency: PlanConcurrency
    public let reserved: ByteCount
    public private(set) var permanent: Scope?

    private let diagnostics: Diagnostics
    private var activeScopes: [Scope] = []
    private var scopeHistory: [Scope] = []
    private var peakBytes = ByteCount(rawValue: 0)

    public init(
        permanent: MemoryPlan? = nil,
        plans: [MemoryPlan] = [],
        concurrency: PlanConcurrency = .single,
        diagnostics: @escaping Diagnostics = { print($0) }
    ) {
        var names = Set<String>()
        if let permanent {
            precondition(
                names.insert(permanent.name).inserted,
                "Duplicate plan name '\(permanent.name)'"
            )
        }
        for plan in plans {
            precondition(
                names.insert(plan.name).inserted,
                "Duplicate plan name '\(plan.name)'"
            )
        }

        self.permanentPlan = permanent
        self.plans = plans
        self.concurrency = concurrency
        self.diagnostics = diagnostics
        self.permanent = nil

        let selected = plans
            .map(\.required)
            .sorted(by: >)
            .prefix(concurrency.maximumCount)
        var reserved = permanent?.required ?? .bytes(0)
        for requirement in selected {
            reserved = reserved + requirement
        }
        self.reserved = reserved

        if let permanent {
            let scope = Scope(plan: permanent, arena: self)
            self.permanent = scope
            scopeHistory.append(scope)
        }
    }

    public var statistics: MemoryStatistics {
        MemoryStatistics(
            reserved: reserved,
            used: currentBytes,
            peak: peakBytes
        )
    }

    public var startupReport: String {
        ReportFormatter.startup(arena: self)
    }

    public var peakUsageReport: String {
        ReportFormatter.peak(arena: self, scopes: scopeHistory)
    }

    public func activate(
        _ plan: MemoryPlan,
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) throws -> Scope {
        let location = SourceLocation(fileID: fileID, line: line)
        guard plans.contains(where: { $0 === plan }) else {
            let message = """
            PixlMemory: Plan is not registered with this arena

            Plan: \(plan.name)
            Tried at:
                \(location.description)
            """
            throw diagnose(message)
        }
        guard !activeScopes.contains(where: { $0.plan === plan }) else {
            let message = """
            PixlMemory: Plan already active

            Plan: \(plan.name)
            Tried at:
                \(location.description)
            """
            throw diagnose(message)
        }
        guard activeScopes.count < concurrency.maximumCount else {
            let active = activeScopes.map(\.name).joined(separator: ", ")
            let required = activeScopes.count + 1
            let message = """
            PixlMemory: Plan concurrency exceeded

            Configured: \(concurrency.maximumCount) plans
            Active:     \(active)
            Tried:      \(plan.name)
            Required:   \(required) plans

            Fix:
                concurrency: .upTo(\(required))

            Tried at:
                \(location.description)
            """
            throw diagnose(message)
        }
        let scope = Scope(plan: plan, arena: self)
        activeScopes.append(scope)
        scopeHistory.append(scope)
        usageDidChange()
        return scope
    }

    func register(_ scope: Scope) {
        scopeHistory.append(scope)
    }

    func scopeDidRelease(_ scope: Scope) {
        activeScopes.removeAll { $0 === scope }
        usageDidChange()
    }

    func usageDidChange() {
        peakBytes = max(peakBytes, currentBytes)
    }

    func diagnose(_ message: String) -> MemoryFailure {
        diagnostics(message)
        return MemoryFailure(message)
    }

    private var currentBytes: ByteCount {
        var total = permanent?.currentBytes.rawValue ?? 0
        for scope in activeScopes where !scope.isReleased {
            let (next, overflow) = total.addingReportingOverflow(
                scope.currentBytes.rawValue
            )
            precondition(!overflow, "Arena usage overflow")
            total = next
        }
        return ByteCount(rawValue: total)
    }
}

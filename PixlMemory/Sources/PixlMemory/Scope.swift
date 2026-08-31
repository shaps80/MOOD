import Swift

/// Runtime lifetime activated from a memory plan.
public final class Scope {
    public let name: String
    public let plan: MemoryPlan

    private weak var arena: Arena?
    private weak var parent: Scope?
    private var states: [ReservationState]
    private var children: [Scope] = []
    private var peakBytes = ByteCount(rawValue: 0)
    private(set) var isReleased = false

    init(plan: MemoryPlan, arena: Arena, parent: Scope? = nil) {
        self.name = plan.name
        self.plan = plan
        self.arena = arena
        self.parent = parent
        states = plan.definitions.map { ReservationState(definition: $0) }
    }

    public var statistics: MemoryStatistics {
        MemoryStatistics(
            reserved: plan.required,
            used: currentBytes,
            peak: peakBytes
        )
    }

    public var report: String {
        ReportFormatter.scope(self)
    }

    public func printReport() {
        print(report)
    }

    public func use<Element>(
        _ type: Element.Type,
        count: Int = 1,
        from reservation: String? = nil,
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) throws {
        precondition(count >= 0, "Use count must be nonnegative")
        try requireLive(at: SourceLocation(fileID: fileID, line: line))
        let typeName = String(reflecting: type)
        guard let index = matchingTyped(typeName, named: reservation) else {
            throw diagnoseMissing(
                subject: reservation ?? String(describing: type),
                fix: "plan.reserve(\(String(describing: type)).self, count: \(count))",
                at: SourceLocation(fileID: fileID, line: line)
            )
        }
        try add(
            UInt64(count),
            to: index,
            unit: String(describing: type),
            at: SourceLocation(fileID: fileID, line: line)
        )
    }

    public func use(
        bytes: ByteCount,
        from reservation: String,
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) throws {
        try requireLive(at: SourceLocation(fileID: fileID, line: line))
        guard let index = states.firstIndex(where: {
            $0.definition.name == reservation
                && $0.definition.typeName == nil
                && $0.definition.childPlan == nil
        }) else {
            throw diagnoseMissing(
                subject: reservation,
                fix: "plan.reserve(bytes: .bytes(\(bytes.rawValue)), named: \"\(reservation)\")",
                at: SourceLocation(fileID: fileID, line: line)
            )
        }
        try add(
            bytes.rawValue,
            to: index,
            unit: "bytes",
            at: SourceLocation(fileID: fileID, line: line)
        )
    }

    public func release<Element>(
        _ type: Element.Type,
        count: Int = 1,
        from reservation: String? = nil,
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) throws {
        precondition(count >= 0, "Release count must be nonnegative")
        try requireLive(at: SourceLocation(fileID: fileID, line: line))
        let typeName = String(reflecting: type)
        guard let index = matchingTyped(typeName, named: reservation) else {
            throw diagnoseMissing(
                subject: reservation ?? String(describing: type),
                fix: "plan.reserve(\(String(describing: type)).self, count: \(count))",
                at: SourceLocation(fileID: fileID, line: line)
            )
        }
        try subtract(
            UInt64(count),
            from: index,
            unit: String(describing: type),
            at: SourceLocation(fileID: fileID, line: line)
        )
    }

    public func release(
        bytes: ByteCount,
        from reservation: String,
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) throws {
        try requireLive(at: SourceLocation(fileID: fileID, line: line))
        guard let index = states.firstIndex(where: {
            $0.definition.name == reservation
                && $0.definition.typeName == nil
                && $0.definition.childPlan == nil
        }) else {
            throw diagnoseMissing(
                subject: reservation,
                fix: "plan.reserve(bytes: .bytes(\(bytes.rawValue)), named: \"\(reservation)\")",
                at: SourceLocation(fileID: fileID, line: line)
            )
        }
        try subtract(
            bytes.rawValue,
            from: index,
            unit: "bytes",
            at: SourceLocation(fileID: fileID, line: line)
        )
    }

    /// Activates one nested plan previously reserved by this plan.
    public func activate(
        _ childPlan: MemoryPlan,
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) throws -> Scope {
        let location = SourceLocation(fileID: fileID, line: line)
        try requireLive(at: location)
        guard let index = states.firstIndex(where: {
            $0.definition.childPlan === childPlan
        }) else {
            throw diagnoseMissing(
                subject: childPlan.name,
                fix: "plan.reserve(\(childPlan.name))",
                at: location
            )
        }
        guard states[index].activeChild == nil else {
            let message = """
            PixlMemory: Scope already active

            Scope: \(childPlan.name)
            Parent: \(name)
            Tried at:
                \(location.description)
            """
            throw arena!.diagnose(message)
        }
        let child = Scope(plan: childPlan, arena: arena!, parent: self)
        states[index].activeChild = child
        children.append(child)
        arena?.register(child)
        noteUsageChanged()
        return child
    }

    /// Releases this scope and every descendant scope.
    public func release() {
        guard !isReleased else { return }
        for child in children.reversed() {
            child.release()
        }
        for index in states.indices {
            states[index].used = 0
            states[index].activeChild = nil
        }
        isReleased = true
        parent?.childDidRelease(self)
        arena?.scopeDidRelease(self)
    }

    var currentBytes: ByteCount {
        var total = UInt64(0)
        for state in states {
            let bytes: UInt64
            if let child = state.activeChild, !child.isReleased {
                bytes = child.currentBytes.rawValue
            } else {
                let (value, overflow) = state.used.multipliedReportingOverflow(
                    by: state.definition.stride
                )
                precondition(!overflow, "Tracked usage overflow")
                bytes = value
            }
            let (next, overflow) = total.addingReportingOverflow(bytes)
            precondition(!overflow, "Tracked usage overflow")
            total = next
        }
        return ByteCount(rawValue: total)
    }

    var descendants: [Scope] {
        children
    }

    private func matchingTyped(_ typeName: String, named name: String?) -> Int? {
        let matches = states.indices.filter { index in
            let definition = states[index].definition
            return definition.typeName == typeName
                && (name == nil || definition.name == name)
        }
        return matches.count == 1 ? matches[0] : nil
    }

    private func add(
        _ amount: UInt64,
        to index: Int,
        unit: String,
        at location: SourceLocation
    ) throws {
        let state = states[index]
        let (required, overflow) = state.used.addingReportingOverflow(amount)
        guard !overflow, required <= state.definition.count else {
            let attempted = overflow ? UInt64.max : required
            throw capacityFailure(
                state: state,
                requested: amount,
                required: attempted,
                unit: unit,
                operation: "use",
                at: location
            )
        }
        states[index].used = required
        states[index].peak = max(states[index].peak, required)
        noteUsageChanged()
    }

    private func subtract(
        _ amount: UInt64,
        from index: Int,
        unit: String,
        at location: SourceLocation
    ) throws {
        let state = states[index]
        guard amount <= state.used else {
            let message = """
            PixlMemory: \(state.definition.name) release exceeded use

            Tried:     release \(amount) \(unit)
            Used:      \(state.used) \(unit)
            Requested: \(amount) \(unit)
            Required:  0 \(unit)

            Tried at:
                \(location.description)
            """
            throw arena!.diagnose(message)
        }
        states[index].used -= amount
        noteUsageChanged()
    }

    private func capacityFailure(
        state: ReservationState,
        requested: UInt64,
        required: UInt64,
        unit: String,
        operation: String,
        at location: SourceLocation
    ) -> MemoryFailure {
        let definition = state.definition
        let typedFix: String
        if let typeName = definition.typeName {
            let shortType = typeName.split(separator: ".").last.map(String.init)
                ?? typeName
            let name = definition.name == shortType
                ? ""
                : ", named: \"\(definition.name)\""
            typedFix = "plan.reserve(\(shortType).self, count: \(required)\(name))"
        } else {
            typedFix = "plan.reserve(bytes: .bytes(\(required)), named: \"\(definition.name)\")"
        }
        let message = """
        PixlMemory: \(definition.name) capacity exceeded

        Tried:     \(operation) \(requested) \(unit)
        Reserved:  \(definition.count) \(unit)
        Used:      \(state.used) \(unit)
        Requested: \(requested) \(unit)
        Required:  \(required) \(unit)

        Reserved at:
            \(definition.source.description)

        Fix:
            \(typedFix)
        """
        return arena!.diagnose(message)
    }

    private func diagnoseMissing(
        subject: String,
        fix: String,
        at location: SourceLocation
    ) -> MemoryFailure {
        let message = """
        PixlMemory: No reservation for \(subject)

        Tried at:
            \(location.description)

        Fix:
            \(fix)
        """
        return arena!.diagnose(message)
    }

    private func requireLive(at location: SourceLocation) throws {
        guard !isReleased else {
            let message = """
            PixlMemory: Scope already released

            Scope: \(name)
            Tried at:
                \(location.description)
            """
            throw arena!.diagnose(message)
        }
    }

    private func childDidRelease(_ child: Scope) {
        for index in states.indices where states[index].activeChild === child {
            states[index].activeChild = nil
        }
        noteUsageChanged()
    }

    private func noteUsageChanged() {
        let current = currentBytes
        peakBytes = max(peakBytes, current)
        parent?.noteUsageChanged()
        arena?.usageDidChange()
    }
}

private struct ReservationState {
    let definition: ReservationDefinition
    var used = UInt64(0)
    var peak = UInt64(0)
    weak var activeChild: Scope?
}

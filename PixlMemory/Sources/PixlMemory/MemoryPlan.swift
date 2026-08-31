import Swift

/// Static description of memory requirements sharing one lifetime.
public final class MemoryPlan: @unchecked Sendable {
    public let name: String
    public let payload: ByteCount
    public let padding: ByteCount
    public let required: ByteCount
    public let alignment: ByteCount

    let definitions: [ReservationDefinition]

    public init(
        _ name: String,
        _ build: (inout MemoryPlanBuilder) -> Void = { _ in }
    ) {
        precondition(!name.isEmpty, "Memory plan name must not be empty")
        var builder = MemoryPlanBuilder()
        build(&builder)

        var names = Set<String>()
        for definition in builder.definitions {
            precondition(
                names.insert(definition.name).inserted,
                "Duplicate reservation name '\(definition.name)' in plan '\(name)'"
            )
        }

        var cursor = UInt64(0)
        var payload = UInt64(0)
        var maximumAlignment = UInt64(1)
        var laidOut: [ReservationDefinition] = []
        laidOut.reserveCapacity(builder.definitions.count)

        for var definition in builder.definitions {
            if definition.payload.rawValue > 0 {
                cursor = Self.aligned(cursor, to: definition.alignment.rawValue)
                maximumAlignment = max(
                    maximumAlignment,
                    definition.alignment.rawValue
                )
            }
            definition.offset = ByteCount(rawValue: cursor)
            let (next, offsetOverflow) = cursor.addingReportingOverflow(
                definition.payload.rawValue
            )
            precondition(!offsetOverflow, "Memory plan size overflow")
            cursor = next
            let (nextPayload, payloadOverflow) = payload.addingReportingOverflow(
                definition.payload.rawValue
            )
            precondition(!payloadOverflow, "Memory plan payload overflow")
            payload = nextPayload
            laidOut.append(definition)
        }

        if cursor > 0 {
            cursor = Self.aligned(cursor, to: maximumAlignment)
        }

        self.name = name
        self.payload = ByteCount(rawValue: payload)
        self.required = ByteCount(rawValue: cursor)
        self.padding = ByteCount(rawValue: cursor - payload)
        self.alignment = ByteCount(rawValue: maximumAlignment)
        definitions = laidOut
    }

    public var report: String {
        ReportFormatter.plan(self)
    }

    public func printReport() {
        print(report)
    }

    private static func aligned(_ value: UInt64, to alignment: UInt64) -> UInt64 {
        let mask = alignment - 1
        let (sum, overflow) = value.addingReportingOverflow(mask)
        precondition(!overflow, "Memory plan alignment overflow")
        return sum & ~mask
    }
}

struct ReservationDefinition: @unchecked Sendable {
    let name: String
    let typeName: String?
    let count: UInt64
    let stride: UInt64
    let payload: ByteCount
    let alignment: ByteCount
    let source: SourceLocation
    let childPlan: MemoryPlan?
    var offset = ByteCount(rawValue: 0)
}

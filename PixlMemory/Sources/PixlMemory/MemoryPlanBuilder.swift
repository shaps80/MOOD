import Swift

/// Builder used to declare one memory plan's requirements.
public struct MemoryPlanBuilder {
    var definitions: [ReservationDefinition] = []

    public mutating func reserve<Element>(
        _ type: Element.Type,
        count: Int,
        named name: String? = nil,
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) {
        precondition(count >= 0, "Reservation count must be nonnegative")
        let stride = UInt64(MemoryLayout<Element>.stride)
        let (payload, overflow) = stride.multipliedReportingOverflow(
            by: UInt64(count)
        )
        precondition(!overflow, "Typed reservation size overflow")
        definitions.append(
            ReservationDefinition(
                name: name ?? String(describing: type),
                typeName: String(reflecting: type),
                count: UInt64(count),
                stride: stride,
                payload: ByteCount(rawValue: payload),
                alignment: ByteCount(
                    rawValue: UInt64(max(1, MemoryLayout<Element>.alignment))
                ),
                source: SourceLocation(fileID: fileID, line: line),
                childPlan: nil
            )
        )
    }

    public mutating func reserve(
        bytes: ByteCount,
        alignment: ByteCount = .bytes(1),
        named name: String,
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) {
        precondition(
            alignment.rawValue > 0 && alignment.rawValue.isPowerOfTwo,
            "Reservation alignment must be a positive power of two"
        )
        definitions.append(
            ReservationDefinition(
                name: name,
                typeName: nil,
                count: bytes.rawValue,
                stride: 1,
                payload: bytes,
                alignment: alignment,
                source: SourceLocation(fileID: fileID, line: line),
                childPlan: nil
            )
        )
    }

    /// Reserves capacity for a nested plan whose scope may have a shorter lifetime.
    public mutating func reserve(
        _ plan: MemoryPlan,
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) {
        definitions.append(
            ReservationDefinition(
                name: plan.name,
                typeName: nil,
                count: plan.required.rawValue,
                stride: 1,
                payload: plan.required,
                alignment: plan.alignment,
                source: SourceLocation(fileID: fileID, line: line),
                childPlan: plan
            )
        )
    }
}

private extension UInt64 {
    var isPowerOfTwo: Bool {
        self != 0 && (self & (self - 1)) == 0
    }
}

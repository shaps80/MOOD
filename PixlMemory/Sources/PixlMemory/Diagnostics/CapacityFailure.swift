import Swift

struct CapacityFailure: Sendable {
    enum Storage: Equatable, Sendable {
        case indexedBuffer
        case rawBuffer
        case densePool
    }

    let storage: Storage
    let region: String
    let operation: String
    let capacity: UInt64
    let used: UInt64
    let required: UInt64
    let reservedBytes: UInt64
    let usedBytes: UInt64
    let requiredBytes: UInt64
    let reservation: SourceLocation
    let access: SourceLocation

    var additional: UInt64 { required - capacity }
    var additionalBytes: UInt64 { requiredBytes - reservedBytes }

    static func indexedBuffer(
        region: String,
        operation: String,
        capacity: UInt64,
        used: UInt64,
        required: UInt64,
        elementStride: UInt64,
        reservation: SourceLocation,
        access: SourceLocation
    ) -> Self {
        Self(
            storage: .indexedBuffer,
            region: region,
            operation: operation,
            capacity: capacity,
            used: used,
            required: required,
            reservedBytes: checkedMultiply(capacity, elementStride),
            usedBytes: checkedMultiply(used, elementStride),
            requiredBytes: checkedMultiply(required, elementStride),
            reservation: reservation,
            access: access
        )
    }

    static func rawBuffer(
        region: String,
        operation: String,
        capacity: UInt64,
        used: UInt64,
        required: UInt64,
        reservation: SourceLocation,
        access: SourceLocation
    ) -> Self {
        Self(
            storage: .rawBuffer,
            region: region,
            operation: operation,
            capacity: capacity,
            used: used,
            required: required,
            reservedBytes: capacity,
            usedBytes: used,
            requiredBytes: required,
            reservation: reservation,
            access: access
        )
    }

    static func densePool(
        region: String,
        operation: String,
        capacity: UInt64,
        used: UInt64,
        required: UInt64,
        elementStride: UInt64,
        elementAlignment: UInt64,
        reservation: SourceLocation,
        access: SourceLocation
    ) -> Self {
        Self(
            storage: .densePool,
            region: region,
            operation: operation,
            capacity: capacity,
            used: used,
            required: required,
            reservedBytes: PoolLayout.calculate(
                capacity: capacity,
                elementStride: elementStride,
                elementAlignment: elementAlignment
            ).required,
            usedBytes: PoolLayout.calculate(
                capacity: used,
                elementStride: elementStride,
                elementAlignment: elementAlignment
            ).required,
            requiredBytes: PoolLayout.calculate(
                capacity: required,
                elementStride: elementStride,
                elementAlignment: elementAlignment
            ).required,
            reservation: reservation,
            access: access
        )
    }
}

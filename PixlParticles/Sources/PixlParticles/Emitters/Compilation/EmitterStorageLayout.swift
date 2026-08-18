import PixlRenderer
import Swift

struct EmitterStorageLayout: Equatable, Sendable {
    let capacity: Int
    let byteCount: Int
    let identifiers: Range<Int>
    let currentPositions: Range<Int>
    let previousPositions: Range<Int>?
    let velocities: Range<Int>?
    let colors: Range<Int>

    init(
        capacity: Int,
        requirements: Set<EmitterStorageRequirement>
    ) {
        let batchCount = (capacity + 3) / 4
        let storesVelocity = requirements.contains(.velocity)
        var builder = Builder()

        identifiers = builder.allocate(
            count: batchCount,
            of: SIMD4<Particle.ID>.self
        )
        currentPositions = builder.allocate(
            count: batchCount,
            of: Vector3Batch.self
        )
        previousPositions = storesVelocity
            ? builder.allocate(count: batchCount, of: Vector3Batch.self)
            : nil
        velocities = storesVelocity
            ? builder.allocate(count: batchCount, of: Vector3Batch.self)
            : nil
        colors = builder.allocate(count: batchCount, of: ColorBatch.self)

        self.capacity = capacity
        byteCount = builder.byteCount
    }
}

private struct Builder {
    private(set) var byteCount = 0

    mutating func allocate<Element>(
        count: Int,
        of type: Element.Type
    ) -> Range<Int> {
        let alignment = MemoryLayout<Element>.alignment
        let remainder = byteCount % alignment
        if remainder != 0 {
            byteCount += alignment - remainder
        }

        let start = byteCount
        byteCount += count * MemoryLayout<Element>.stride
        return start..<byteCount
    }
}

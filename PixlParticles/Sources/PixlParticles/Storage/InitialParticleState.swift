import Swift

final class InitialParticleState {
    let particleCount: Int

    private let positions: UnsafeMutableBufferPointer<Vector3Batch>

    init(
        particleCount: Int,
        copying source: UnsafeMutableBufferPointer<Vector3Batch>
    ) {
        self.particleCount = particleCount
        positions = .allocate(capacity: source.count)

        for index in source.indices {
            positions.initializeElement(at: index, to: source[index])
        }
    }

    deinit {
        positions.deallocate()
    }

    subscript(batch index: Int) -> Vector3Batch {
        positions[index]
    }
}

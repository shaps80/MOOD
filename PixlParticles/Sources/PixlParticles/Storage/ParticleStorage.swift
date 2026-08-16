import Swift

final class ParticleStorage {
    let count: Int

    private let batchCount: Int
    private let ids: UnsafeMutableBufferPointer<SIMD4<Particle.ID>>
    private let positions: UnsafeMutableBufferPointer<Vector3Batch>
    private let previousPositions: UnsafeMutableBufferPointer<Vector3Batch>
    private let velocities: UnsafeMutableBufferPointer<Vector3Batch>

    init(
        count: Int,
        particleAt: (Int) -> Particle
    ) {
        self.count = count
        batchCount = (count + 3) / 4
        ids = .allocate(capacity: batchCount)
        positions = .allocate(capacity: batchCount)
        previousPositions = .allocate(capacity: batchCount)
        velocities = .allocate(capacity: batchCount)

        for batchIndex in 0..<batchCount {
            var batchIDs = SIMD4<Particle.ID>(repeating: 0)
            var batchPositions = Vector3Batch(repeating: .zero)
            var batchPreviousPositions = Vector3Batch(repeating: .zero)
            var batchVelocities = Vector3Batch(repeating: .zero)

            for lane in 0..<4 {
                let index = batchIndex * 4 + lane
                guard index < count else { break }

                let particle = particleAt(index)
                batchIDs[lane] = particle.id
                batchPositions[lane] = particle.position
                batchPreviousPositions[lane] = particle.previousPosition
                batchVelocities[lane] = particle.velocity
            }

            ids.initializeElement(at: batchIndex, to: batchIDs)
            positions.initializeElement(at: batchIndex, to: batchPositions)
            previousPositions.initializeElement(
                at: batchIndex,
                to: batchPreviousPositions
            )
            velocities.initializeElement(at: batchIndex, to: batchVelocities)
        }
    }

    init(copying source: ParticleStorage) {
        count = source.count
        batchCount = source.batchCount
        ids = .allocate(capacity: batchCount)
        positions = .allocate(capacity: batchCount)
        previousPositions = .allocate(capacity: batchCount)
        velocities = .allocate(capacity: batchCount)

        for index in 0..<batchCount {
            ids.initializeElement(at: index, to: source.ids[index])
            positions.initializeElement(at: index, to: source.positions[index])
            previousPositions.initializeElement(
                at: index,
                to: source.previousPositions[index]
            )
            velocities.initializeElement(at: index, to: source.velocities[index])
        }
    }

    deinit {
        ids.deallocate()
        positions.deallocate()
        previousPositions.deallocate()
        velocities.deallocate()
    }

    func copyState(from source: ParticleStorage) {
        precondition(count == source.count)

        for index in 0..<batchCount {
            ids[index] = source.ids[index]
            positions[index] = source.positions[index]
            previousPositions[index] = source.previousPositions[index]
            velocities[index] = source.velocities[index]
        }
    }

    @inline(__always)
    func advance(by delta: Float) {
        for index in 0..<batchCount {
            previousPositions[index] = positions[index]
            positions[index].x += velocities[index].x * delta
            positions[index].y += velocities[index].y * delta
            positions[index].z += velocities[index].z * delta
        }
    }

    func resetInterpolation() {
        for index in 0..<batchCount {
            previousPositions[index] = positions[index]
        }
    }

    func particles() -> [Particle] {
        Array(unsafeUninitializedCapacity: count) { buffer, initializedCount in
            for index in 0..<count {
                let batch = index / 4
                let lane = index % 4
                buffer.initializeElement(
                    at: index,
                    to: Particle(
                        id: ids[batch][lane],
                        previousPosition: previousPositions[batch][lane],
                        position: positions[batch][lane],
                        velocity: velocities[batch][lane]
                    )
                )
            }

            initializedCount = count
        }
    }
}

import PixlRenderer
import Swift

final class ParticleStorage {
    let count: Int

    private let batchCount: Int
    private let idsStorage: HostBuffer
    private var previousPositionStorage: HostBuffer
    private var positionStorage: HostBuffer
    private let colorStorage: HostBuffer
    private let ids: UnsafeMutableBufferPointer<SIMD4<Particle.ID>>
    private var positions: UnsafeMutableBufferPointer<Vector3Batch>
    private var previousPositions: UnsafeMutableBufferPointer<Vector3Batch>
    private let colors: UnsafeMutableBufferPointer<ColorBatch>
    private let velocities: UnsafeMutableBufferPointer<Vector3Batch>

    init(
        count: Int,
        particleAt: (Int) -> Particle
    ) {
        self.count = count
        batchCount = (count + 3) / 4
        previousPositionStorage = HostBuffer(
            byteCount: batchCount * MemoryLayout<Vector3Batch>.stride
        )
        positionStorage = HostBuffer(
            byteCount: batchCount * MemoryLayout<Vector3Batch>.stride
        )
        colorStorage = HostBuffer(
            byteCount: batchCount * MemoryLayout<ColorBatch>.stride
        )
        idsStorage = HostBuffer(
            byteCount: batchCount * MemoryLayout<SIMD4<Particle.ID>>.stride
        )
        ids = idsStorage.bindMemory(
            to: SIMD4<Particle.ID>.self,
            count: batchCount
        )
        positions = positionStorage.bindMemory(
            to: Vector3Batch.self,
            count: batchCount
        )
        previousPositions = previousPositionStorage.bindMemory(
            to: Vector3Batch.self,
            count: batchCount
        )
        colors = colorStorage.bindMemory(
            to: ColorBatch.self,
            count: batchCount
        )
        velocities = .allocate(capacity: batchCount)

        for batchIndex in 0..<batchCount {
            var batchIDs = SIMD4<Particle.ID>(repeating: 0)
            var batchPositions = Vector3Batch(repeating: .zero)
            var batchPreviousPositions = Vector3Batch(repeating: .zero)
            var batchColors = ColorBatch(repeating: .white)
            var batchVelocities = Vector3Batch(repeating: .zero)

            for lane in 0..<4 {
                let index = batchIndex * 4 + lane
                guard index < count else { break }

                let particle = particleAt(index)
                batchIDs[lane] = particle.id
                batchPositions[lane] = particle.position
                batchPreviousPositions[lane] = particle.previousPosition
                batchColors[lane] = particle.color
                batchVelocities[lane] = particle.velocity
            }

            ids.initializeElement(at: batchIndex, to: batchIDs)
            positions.initializeElement(at: batchIndex, to: batchPositions)
            previousPositions.initializeElement(
                at: batchIndex,
                to: batchPreviousPositions
            )
            colors.initializeElement(at: batchIndex, to: batchColors)
            velocities.initializeElement(at: batchIndex, to: batchVelocities)
        }
    }

    deinit {
        ids.deinitialize()
        positions.deinitialize()
        previousPositions.deinitialize()
        colors.deinitialize()
        velocities.deinitialize()
        velocities.deallocate()
    }

    func initialState() -> InitialParticleState {
        InitialParticleState(
            particleCount: count,
            copying: positions
        )
    }

    func restore(from state: InitialParticleState) {
        precondition(count == state.particleCount)

        for index in 0..<batchCount {
            let initialPosition = state[batch: index]
            positions[index] = initialPosition
            previousPositions[index] = initialPosition
        }
    }

    @inline(__always)
    func advance(by delta: Float) {
        for index in 0..<batchCount {
            previousPositions[index].x = positions[index].x
                + velocities[index].x * delta
            previousPositions[index].y = positions[index].y
                + velocities[index].y * delta
            previousPositions[index].z = positions[index].z
                + velocities[index].z * delta
        }

        let oldPreviousPositions = previousPositions
        previousPositions = positions
        positions = oldPreviousPositions

        let oldPreviousStorage = previousPositionStorage
        previousPositionStorage = positionStorage
        positionStorage = oldPreviousStorage
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
                        velocity: velocities[batch][lane],
                        color: colors[batch][lane]
                    )
                )
            }

            initializedCount = count
        }
    }

    func withRenderingData<Result: ~Copyable>(
        _ body: (PointBuffers, Int) throws -> Result
    ) rethrows -> Result {
        try body(
            PointBuffers(
                previousPositions: previousPositionStorage,
                currentPositions: positionStorage,
                colors: colorStorage,
                ids: idsStorage
            ),
            count
        )
    }
}

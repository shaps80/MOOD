import PixlRenderer
import Swift

final class ParticleStorage {
    let capacity: Int
    private(set) var count: Int

    private let capacityBatchCount: Int
    private var liveBatchCount: Int
    private let idsStorage: HostBuffer
    private var previousPositionStorage: HostBuffer?
    private var positionStorage: HostBuffer
    private let colorStorage: HostBuffer
    private let ids: UnsafeMutableBufferPointer<SIMD4<UInt32>>
    private var positions: UnsafeMutableBufferPointer<Vector3Batch>
    private var previousPositions: UnsafeMutableBufferPointer<Vector3Batch>?
    private let colors: UnsafeMutableBufferPointer<ColorBatch>
    private let velocities: UnsafeMutableBufferPointer<Vector3Batch>?

    init(
        count: Int,
        storesVelocity: Bool = true,
        particleAt: (Int) -> Particle
    ) {
        capacity = count
        self.count = count
        capacityBatchCount = (count + 3) / 4
        liveBatchCount = capacityBatchCount
        previousPositionStorage = storesVelocity
            ? HostBuffer(
                byteCount: capacityBatchCount * MemoryLayout<Vector3Batch>.stride
            )
            : nil
        positionStorage = HostBuffer(
            byteCount: capacityBatchCount * MemoryLayout<Vector3Batch>.stride
        )
        colorStorage = HostBuffer(
            byteCount: capacityBatchCount * MemoryLayout<ColorBatch>.stride
        )
        idsStorage = HostBuffer(
            byteCount: capacityBatchCount * MemoryLayout<SIMD4<UInt32>>.stride
        )
        ids = idsStorage.bindMemory(
            to: SIMD4<UInt32>.self,
            count: capacityBatchCount
        )
        positions = positionStorage.bindMemory(
            to: Vector3Batch.self,
            count: capacityBatchCount
        )
        previousPositions = previousPositionStorage?.bindMemory(
            to: Vector3Batch.self,
            count: capacityBatchCount
        )
        colors = colorStorage.bindMemory(
            to: ColorBatch.self,
            count: capacityBatchCount
        )
        velocities = storesVelocity
            ? .allocate(capacity: capacityBatchCount)
            : nil

        for batchIndex in 0..<capacityBatchCount {
            var batchIDs = SIMD4<UInt32>(repeating: 0)
            var batchPositions = Vector3Batch(repeating: .zero)
            var batchPreviousPositions = Vector3Batch(repeating: .zero)
            var batchColors = ColorBatch(repeating: .white)
            var batchVelocities = Vector3Batch(repeating: .zero)

            for lane in 0..<4 {
                let index = batchIndex * 4 + lane
                guard index < count else { break }

                let particle = particleAt(index)
                batchIDs[lane] = UInt32(truncatingIfNeeded: particle.id)
                batchPositions[lane] = particle.position
                batchPreviousPositions[lane] = particle.previousPosition
                batchColors[lane] = particle.color
                batchVelocities[lane] = particle.velocity
            }

            ids.initializeElement(at: batchIndex, to: batchIDs)
            positions.initializeElement(at: batchIndex, to: batchPositions)
            previousPositions?.initializeElement(
                at: batchIndex,
                to: batchPreviousPositions
            )
            colors.initializeElement(at: batchIndex, to: batchColors)
            velocities?.initializeElement(at: batchIndex, to: batchVelocities)
        }
    }

    deinit {
        ids.deinitialize()
        positions.deinitialize()
        previousPositions?.deinitialize()
        colors.deinitialize()
        velocities?.deinitialize()
        velocities?.deallocate()
    }

    func initialState() -> InitialParticleState {
        InitialParticleState(
            particleCount: capacity,
            copying: positions
        )
    }

    func restore(from state: InitialParticleState) {
        precondition(capacity == state.particleCount)

        for index in 0..<capacityBatchCount {
            let initialPosition = state[batch: index]
            positions[index] = initialPosition
            previousPositions?[index] = initialPosition
        }
    }

    @inline(__always)
    func advance(by delta: Float) {
        guard var previousPositions, let velocities else { return }

        for index in 0..<liveBatchCount {
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
        self.previousPositions = previousPositions

        let oldPreviousStorage = previousPositionStorage!
        previousPositionStorage = positionStorage
        positionStorage = oldPreviousStorage
    }

    func resetInterpolation() {
        for index in 0..<liveBatchCount {
            previousPositions?[index] = positions[index]
        }
    }

    func particles(
        id: (UInt32) -> Particle.ID
    ) -> [Particle] {
        Array(unsafeUninitializedCapacity: count) { buffer, initializedCount in
            for index in 0..<count {
                let batch = index / 4
                let lane = index % 4
                buffer.initializeElement(
                    at: index,
                    to: Particle(
                        id: id(ids[batch][lane]),
                        previousPosition: previousPositions?[batch][lane]
                            ?? positions[batch][lane],
                        position: positions[batch][lane],
                        velocity: velocities?[batch][lane] ?? .zero,
                        color: colors[batch][lane]
                    )
                )
            }

            initializedCount = count
        }
    }

    @inline(__always)
    func slot(at index: Int) -> UInt32 {
        ids[index / 4][index % 4]
    }

    @inline(__always)
    func removeStationary(at index: Int) -> UInt32? {
        precondition(index >= 0 && index < count)

        let lastIndex = count - 1
        let movedSlot: UInt32?
        if index == lastIndex {
            movedSlot = nil
        } else {
            movedSlot = slot(at: lastIndex)
            moveStationary(from: lastIndex, to: index)
        }
        setCount(lastIndex)
        return movedSlot
    }

    @inline(__always)
    func removeMoving(at index: Int) -> UInt32? {
        precondition(index >= 0 && index < count)

        let lastIndex = count - 1
        let movedSlot: UInt32?
        if index == lastIndex {
            movedSlot = nil
        } else {
            movedSlot = slot(at: lastIndex)
            moveMoving(from: lastIndex, to: index)
        }
        setCount(lastIndex)
        return movedSlot
    }

    @inline(__always)
    private func moveStationary(from source: Int, to destination: Int) {
        let sourceBatch = source / 4
        let sourceLane = source % 4
        let destinationBatch = destination / 4
        let destinationLane = destination % 4

        ids[destinationBatch][destinationLane] = ids[sourceBatch][sourceLane]
        positions[destinationBatch][destinationLane] =
            positions[sourceBatch][sourceLane]
        colors[destinationBatch][destinationLane] = colors[sourceBatch][sourceLane]
    }

    @inline(__always)
    private func moveMoving(from source: Int, to destination: Int) {
        moveStationary(from: source, to: destination)

        let sourceBatch = source / 4
        let sourceLane = source % 4
        let destinationBatch = destination / 4
        let destinationLane = destination % 4

        previousPositions![destinationBatch][destinationLane] =
            previousPositions![sourceBatch][sourceLane]
        velocities![destinationBatch][destinationLane] =
            velocities![sourceBatch][sourceLane]
    }

    @inline(__always)
    func appendStationary(_ particle: Particle, slot: UInt32) {
        precondition(count < capacity)

        let index = count
        let batch = index / 4
        let lane = index % 4
        ids[batch][lane] = slot
        positions[batch][lane] = particle.position
        colors[batch][lane] = particle.color
        setCount(index + 1)
    }

    @inline(__always)
    func appendMoving(_ particle: Particle, slot: UInt32) {
        precondition(count < capacity)

        let index = count
        let batch = index / 4
        let lane = index % 4
        ids[batch][lane] = slot
        positions[batch][lane] = particle.position
        colors[batch][lane] = particle.color
        previousPositions![batch][lane] = particle.previousPosition
        velocities![batch][lane] = particle.velocity
        setCount(index + 1)
    }

    func withRenderingData<Result: ~Copyable>(
        _ body: (ParticleBuffers, Int) throws -> Result
    ) rethrows -> Result {
        try body(
            ParticleBuffers(
                previousPositions: previousPositionStorage ?? positionStorage,
                currentPositions: positionStorage,
                colors: colorStorage,
                ids: idsStorage
            ),
            count
        )
    }

    @inline(__always)
    private func setCount(_ count: Int) {
        self.count = count
        liveBatchCount = (count + 3) / 4
    }
}

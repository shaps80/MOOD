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
    private let lifetimes: UnsafeMutableBufferPointer<SIMD4<UInt32>>

    init(
        capacity: Int,
        storesVelocity: Bool = true
    ) {
        self.capacity = capacity
        count = 0
        capacityBatchCount = (capacity + 3) / 4
        liveBatchCount = 0
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
        lifetimes = .allocate(capacity: capacityBatchCount)

        for batchIndex in 0..<capacityBatchCount {
            ids.initializeElement(
                at: batchIndex,
                to: SIMD4<UInt32>(repeating: 0)
            )
            positions.initializeElement(
                at: batchIndex,
                to: Vector3Batch(repeating: .zero)
            )
            previousPositions?.initializeElement(
                at: batchIndex,
                to: Vector3Batch(repeating: .zero)
            )
            colors.initializeElement(
                at: batchIndex,
                to: ColorBatch(repeating: .white)
            )
            velocities?.initializeElement(
                at: batchIndex,
                to: Vector3Batch(repeating: .zero)
            )
            lifetimes.initializeElement(
                at: batchIndex,
                to: SIMD4<UInt32>(repeating: 0)
            )
        }
    }

    deinit {
        ids.deinitialize()
        positions.deinitialize()
        previousPositions?.deinitialize()
        colors.deinitialize()
        velocities?.deinitialize()
        velocities?.deallocate()
        lifetimes.deinitialize()
        lifetimes.deallocate()
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
    func advance(
        by delta: Float,
        collectingExpiredSlotsInto expiredSlots: UnsafeMutableBufferPointer<UInt32>
    ) -> Int {
        let one = SIMD4<UInt32>(repeating: 1)
        let fullBatchCount = count / 4
        var expiredCount = 0

        if var previousPositions, let velocities {
            for index in 0..<fullBatchCount {
                let remaining = lifetimes[index] &- one
                lifetimes[index] = remaining
                collectExpiredSlots(
                    in: remaining,
                    batch: index,
                    laneCount: 4,
                    into: expiredSlots,
                    count: &expiredCount
                )

                previousPositions[index].x = positions[index].x
                    + velocities[index].x * delta
                previousPositions[index].y = positions[index].y
                    + velocities[index].y * delta
                previousPositions[index].z = positions[index].z
                    + velocities[index].z * delta
            }

            if fullBatchCount < liveBatchCount {
                let remaining = lifetimes[fullBatchCount] &- one
                lifetimes[fullBatchCount] = remaining
                collectExpiredSlots(
                    in: remaining,
                    batch: fullBatchCount,
                    laneCount: count % 4,
                    into: expiredSlots,
                    count: &expiredCount
                )

                previousPositions[fullBatchCount].x = positions[fullBatchCount].x
                    + velocities[fullBatchCount].x * delta
                previousPositions[fullBatchCount].y = positions[fullBatchCount].y
                    + velocities[fullBatchCount].y * delta
                previousPositions[fullBatchCount].z = positions[fullBatchCount].z
                    + velocities[fullBatchCount].z * delta
            }

            let oldPreviousPositions = previousPositions
            previousPositions = positions
            positions = oldPreviousPositions
            self.previousPositions = previousPositions

            let oldPreviousStorage = previousPositionStorage!
            previousPositionStorage = positionStorage
            positionStorage = oldPreviousStorage
        } else {
            for index in 0..<fullBatchCount {
                let remaining = lifetimes[index] &- one
                lifetimes[index] = remaining
                collectExpiredSlots(
                    in: remaining,
                    batch: index,
                    laneCount: 4,
                    into: expiredSlots,
                    count: &expiredCount
                )
            }

            if fullBatchCount < liveBatchCount {
                let remaining = lifetimes[fullBatchCount] &- one
                lifetimes[fullBatchCount] = remaining
                collectExpiredSlots(
                    in: remaining,
                    batch: fullBatchCount,
                    laneCount: count % 4,
                    into: expiredSlots,
                    count: &expiredCount
                )
            }
        }

        return expiredCount
    }

    @inline(__always)
    private func collectExpiredSlots(
        in remaining: SIMD4<UInt32>,
        batch: Int,
        laneCount: Int,
        into expiredSlots: UnsafeMutableBufferPointer<UInt32>,
        count: inout Int
    ) {
        guard remaining.min() == 0 else { return }

        for lane in 0..<laneCount where remaining[lane] == 0 {
            expiredSlots[count] = ids[batch][lane]
            count += 1
        }
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
        lifetimes[destinationBatch][destinationLane] =
            lifetimes[sourceBatch][sourceLane]
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
    func appendStationary(
        _ particle: Particle,
        slot: UInt32,
        lifetimeTicks: UInt32
    ) {
        precondition(count < capacity)

        let index = count
        let batch = index / 4
        let lane = index % 4
        ids[batch][lane] = slot
        lifetimes[batch][lane] = lifetimeTicks
        positions[batch][lane] = particle.position
        colors[batch][lane] = particle.color
        setCount(index + 1)
    }

    @inline(__always)
    func appendMoving(
        _ particle: Particle,
        slot: UInt32,
        lifetimeTicks: UInt32
    ) {
        precondition(count < capacity)

        let index = count
        let batch = index / 4
        let lane = index % 4
        ids[batch][lane] = slot
        lifetimes[batch][lane] = lifetimeTicks
        positions[batch][lane] = particle.position
        colors[batch][lane] = particle.color
        previousPositions![batch][lane] = particle.previousPosition
        velocities![batch][lane] = particle.velocity
        setCount(index + 1)
    }

    @inline(__always)
    func replaceStationary(
        at index: Int,
        with particle: Particle,
        slot: UInt32,
        lifetimeTicks: UInt32
    ) {
        let batch = index / 4
        let lane = index % 4
        ids[batch][lane] = slot
        lifetimes[batch][lane] = lifetimeTicks
        positions[batch][lane] = particle.position
        colors[batch][lane] = particle.color
    }

    @inline(__always)
    func replaceMoving(
        at index: Int,
        with particle: Particle,
        slot: UInt32,
        lifetimeTicks: UInt32
    ) {
        replaceStationary(
            at: index,
            with: particle,
            slot: slot,
            lifetimeTicks: lifetimeTicks
        )
        let batch = index / 4
        let lane = index % 4
        previousPositions![batch][lane] = particle.previousPosition
        velocities![batch][lane] = particle.velocity
    }

    func removeAll() {
        setCount(0)
    }

    func withRenderingData<Result: ~Copyable>(
        _ body: (ParticleBuffers, Int) throws -> Result
    ) rethrows -> Result {
        try body(
            ParticleBuffers(
                capacity: capacity,
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

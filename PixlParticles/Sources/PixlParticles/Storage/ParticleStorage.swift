import PixlRenderer
import Swift

final class ParticleStorage {
    let capacity: Int
    private(set) var count: Int

    private let capacityBatchCount: Int
    private var liveBatchCount: Int
    private let idsStorage: HostBuffer
    private let displacementStorage: HostBuffer?
    private let positionStorage: HostBuffer
    private let colorStorage: HostBuffer
    private let ids: UnsafeMutableBufferPointer<SIMD4<UInt32>>
    private let positions: UnsafeMutableBufferPointer<Vector3Batch>
    private let displacements: UnsafeMutableBufferPointer<SIMD4<UInt32>>?
    private let colors: UnsafeMutableBufferPointer<SIMD4<UInt16>>
    private let velocityStorage: HostBuffer?
    private let velocities: UnsafeMutableBufferPointer<SIMD4<UInt32>>?
    private var codec: PackedVector3
    private var palette: ParticleColorPalette
    private var displacementScale: Float = 0

    init(
        capacity: Int,
        storesVelocity: Bool = true,
        velocityPacking: PackedVector3 = .init(maximumMagnitude: 1),
        palette: ParticleColorPalette = .init([.white])
    ) {
        self.capacity = capacity
        codec = velocityPacking
        self.palette = palette
        count = 0
        capacityBatchCount = (capacity + 3) / 4
        liveBatchCount = 0
        displacementStorage = storesVelocity
            ? HostBuffer(
                byteCount: capacityBatchCount * MemoryLayout<SIMD4<UInt32>>.stride
            )
            : nil
        positionStorage = HostBuffer(
            byteCount: capacityBatchCount * MemoryLayout<Vector3Batch>.stride
        )
        colorStorage = HostBuffer(
            byteCount: capacityBatchCount * MemoryLayout<SIMD4<UInt16>>.stride
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
        displacements = displacementStorage?.bindMemory(
            to: SIMD4<UInt32>.self,
            count: capacityBatchCount
        )
        colors = colorStorage.bindMemory(
            to: SIMD4<UInt16>.self,
            count: capacityBatchCount
        )
        velocityStorage = storesVelocity
            ? HostBuffer(byteCount: capacityBatchCount * MemoryLayout<SIMD4<UInt32>>.stride)
            : nil
        velocities = velocityStorage?.bindMemory(to: SIMD4<UInt32>.self, count: capacityBatchCount)

        for batchIndex in 0..<capacityBatchCount {
            ids.initializeElement(
                at: batchIndex,
                to: SIMD4<UInt32>(repeating: 0)
            )
            positions.initializeElement(
                at: batchIndex,
                to: Vector3Batch(repeating: .zero)
            )
            displacements?.initializeElement(
                at: batchIndex,
                to: .zero
            )
            colors.initializeElement(
                at: batchIndex,
                to: .zero
            )
            velocities?.initializeElement(
                at: batchIndex,
                to: .zero
            )
        }
    }

    deinit {
        ids.deinitialize()
        positions.deinitialize()
        displacements?.deinitialize()
        colors.deinitialize()
        velocities?.deinitialize()
    }

    var paletteByteCount: Int { palette.storage.byteCount }

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
            displacements?[index] = .zero
        }
    }

    func configure(velocityPacking: PackedVector3, palette: ParticleColorPalette) {
        precondition(count == 0)
        codec = velocityPacking
        self.palette = palette
        displacementScale = 0
    }

    @inline(__always)
    func advance(by delta: Float, executor: (any SimulationExecutor)? = nil) {
        guard let displacements, let velocities else { return }
        // Current linear motion uses the same quantized components for velocity
        // and this tick's displacement; only their shared scales differ.
        displacementScale = codec.scale * delta
        var context = IntegrationJob(
            positions: positions, displacements: displacements,
            velocities: velocities, codec: codec, delta: delta
        )
        if let executor {
            withUnsafePointer(to: &context) { pointer in
                executor.execute(SimulationJob(count: liveBatchCount, kind: .integration, context: pointer) {
                    pointer, range in
                    pointer.assumingMemoryBound(to: IntegrationJob.self).pointee.run(range)
                })
            }
        } else {
            context.run(0..<liveBatchCount)
        }
    }

    func resetInterpolation() {
        for index in 0..<liveBatchCount { displacements?[index] = .zero }
    }

    @inline(__always)
    private func previousPosition(batch: Int, lane: Int) -> Vec3 {
        guard let displacements else { return positions[batch][lane] }
        let word = displacements[batch][lane]
        // Decode directly with the displacement scale (also used by shaders).
        let delta = Vec3(
            Float(Int32(bitPattern: word << 22) >> 22),
            Float(Int32(bitPattern: word << 12) >> 22),
            Float(Int32(bitPattern: word << 2) >> 22)
        ) * displacementScale
        return positions[batch][lane] - delta
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
                        previousPosition: previousPosition(batch: batch, lane: lane),
                        position: positions[batch][lane],
                        velocity: velocities.map { codec.unpack($0[batch][lane]) } ?? .zero,
                        color: palette[colors[batch][lane]]
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

        displacements![destinationBatch][destinationLane] =
            displacements![sourceBatch][sourceLane]
        velocities![destinationBatch][destinationLane] =
            velocities![sourceBatch][sourceLane]
    }

    @inline(__always)
    func appendStationary(
        _ particle: Particle,
        slot: UInt32
    ) {
        precondition(count < capacity)

        let index = count
        let batch = index / 4
        let lane = index % 4
        ids[batch][lane] = slot
        positions[batch][lane] = particle.position
        colors[batch][lane] = palette.index(of: particle.color)
        setCount(index + 1)
    }

    @inline(__always)
    func appendMoving(
        _ particle: Particle,
        slot: UInt32
    ) {
        precondition(count < capacity)

        let index = count
        let batch = index / 4
        let lane = index % 4
        ids[batch][lane] = slot
        positions[batch][lane] = particle.position
        colors[batch][lane] = palette.index(of: particle.color)
        let word = codec.pack(particle.velocity)
        displacements![batch][lane] = particle.previousPosition == particle.position ? 0 : word
        velocities![batch][lane] = word
        setCount(index + 1)
    }

    @inline(__always)
    func replaceStationary(
        at index: Int,
        with particle: Particle,
        slot: UInt32
    ) {
        let batch = index / 4
        let lane = index % 4
        ids[batch][lane] = slot
        positions[batch][lane] = particle.position
        colors[batch][lane] = palette.index(of: particle.color)
    }

    @inline(__always)
    func replaceMoving(
        at index: Int,
        with particle: Particle,
        slot: UInt32
    ) {
        replaceStationary(
            at: index,
            with: particle,
            slot: slot
        )
        let batch = index / 4
        let lane = index % 4
        let word = codec.pack(particle.velocity)
        displacements![batch][lane] = particle.previousPosition == particle.position ? 0 : word
        velocities![batch][lane] = word
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
                displacements: displacementStorage ?? idsStorage,
                displacementScale: displacementScale,
                currentPositions: positionStorage,
                colorIndices: colorStorage,
                colorPalette: palette.storage,
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

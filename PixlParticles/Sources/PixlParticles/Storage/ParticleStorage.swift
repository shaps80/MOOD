import PixlRenderer
import Swift

final class ParticleStorage {
    let count: Int

    private let batchCount: Int
    private let ids: UnsafeMutableBufferPointer<SIMD4<Particle.ID>>
    private let positions: UnsafeMutableBufferPointer<Vector3Batch>
    private let previousPositions: UnsafeMutableBufferPointer<Vector3Batch>
    private let colors: UnsafeMutableBufferPointer<ColorBatch>
    private let previousColors: UnsafeMutableBufferPointer<ColorBatch>
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
        colors = .allocate(capacity: batchCount)
        previousColors = .allocate(capacity: batchCount)
        velocities = .allocate(capacity: batchCount)

        for batchIndex in 0..<batchCount {
            var batchIDs = SIMD4<Particle.ID>(repeating: 0)
            var batchPositions = Vector3Batch(repeating: .zero)
            var batchPreviousPositions = Vector3Batch(repeating: .zero)
            var batchColors = ColorBatch(repeating: .white)
            var batchPreviousColors = ColorBatch(repeating: .white)
            var batchVelocities = Vector3Batch(repeating: .zero)

            for lane in 0..<4 {
                let index = batchIndex * 4 + lane
                guard index < count else { break }

                let particle = particleAt(index)
                batchIDs[lane] = particle.id
                batchPositions[lane] = particle.position
                batchPreviousPositions[lane] = particle.previousPosition
                batchColors[lane] = particle.color
                batchPreviousColors[lane] = particle.previousColor
                batchVelocities[lane] = particle.velocity
            }

            ids.initializeElement(at: batchIndex, to: batchIDs)
            positions.initializeElement(at: batchIndex, to: batchPositions)
            previousPositions.initializeElement(
                at: batchIndex,
                to: batchPreviousPositions
            )
            colors.initializeElement(at: batchIndex, to: batchColors)
            previousColors.initializeElement(
                at: batchIndex,
                to: batchPreviousColors
            )
            velocities.initializeElement(at: batchIndex, to: batchVelocities)
        }
    }

    deinit {
        ids.deallocate()
        positions.deallocate()
        previousPositions.deallocate()
        colors.deallocate()
        previousColors.deallocate()
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
            previousPositions[index] = positions[index]
            previousColors[index] = colors[index]
            positions[index].x += velocities[index].x * delta
            positions[index].y += velocities[index].y * delta
            positions[index].z += velocities[index].z * delta
        }
    }

    func resetInterpolation() {
        for index in 0..<batchCount {
            previousPositions[index] = positions[index]
            previousColors[index] = colors[index]
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
                        previousColor: previousColors[batch][lane],
                        color: colors[batch][lane]
                    )
                )
            }

            initializedCount = count
        }
    }

    func withRenderingData<Result: ~Copyable>(
        _ body: (
            Span<Vector3Batch>,
            Span<Vector3Batch>,
            UnsafeBufferPointer<ColorBatch>,
            UnsafeBufferPointer<ColorBatch>,
            Span<SIMD4<UInt64>>,
            Int
        ) throws -> Result
    ) rethrows -> Result {
        let previous = UnsafeBufferPointer(
            start: previousPositions.baseAddress,
            count: batchCount
        )
        let current = UnsafeBufferPointer(
            start: positions.baseAddress,
            count: batchCount
        )
        let ids = UnsafeBufferPointer(
            start: self.ids.baseAddress,
            count: batchCount
        )
        let previousColors = UnsafeBufferPointer(
            start: self.previousColors.baseAddress,
            count: batchCount
        )
        let colors = UnsafeBufferPointer(
            start: self.colors.baseAddress,
            count: batchCount
        )

        return try body(
            unsafe Span(_unsafeElements: previous),
            unsafe Span(_unsafeElements: current),
            previousColors,
            colors,
            unsafe Span(_unsafeElements: ids),
            count
        )
    }
}

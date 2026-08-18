import PixlParticles
import PixlRenderer
import Swift

@main
@MainActor
struct HandoffBenchmarks {
    private static let rendererModes: [(
        name: String,
        renderer: ParticleRenderer
    )] = [
        ("Point", .init(mode: .point)),
        ("Billboard", .init(mode: .billboard)),
    ]
    private static let particleCounts = [
        10_000,
        100_000,
        1_000_000,
        2_000_000,
        6_000_000,
    ]
    private static let iterationCount = 1_000_000
    private static let warmupCount = 1_000
    private static let sampleCount = 5

    static func main() {
        for mode in rendererModes {
            for particleCount in particleCounts {
                benchmark(
                    name: mode.name,
                    particleRenderer: mode.renderer,
                    particleCount: particleCount
                )
            }
        }
    }

    private static func benchmark(
        name: String,
        particleRenderer: ParticleRenderer,
        particleCount: Int
    ) {
        let system = System(
            seed: 0x0123456789ABCDEF,
            particleCount: particleCount,
            spawnRegion: .sphere(radius: 100),
            duration: .seconds(60),
            storesRewindState: false
        )
        let backend = BenchmarkBackend()
        let renderer = PixlParticles.Renderer(backend: backend)
        let matrix = Matrix4x4(
            x: [1, 0, 0, 0],
            y: [0, 1, 0, 0],
            z: [0, 0, 1, 0],
            w: [0, 0, 0, 1]
        )
        let camera = CameraFrame(
            viewProjection: matrix,
            position: .zero,
            right: [1, 0, 0],
            up: [0, 1, 0],
            viewport: .init(width: 1920, height: 1080)
        )

        for _ in 0..<warmupCount {
            try! renderer.render(
                system,
                renderer: particleRenderer,
                values: .init(),
                interpolation: 0.5,
                cullingViewProjection: matrix,
                camera: camera
            )
        }

        var samples: [Double] = []
        samples.reserveCapacity(sampleCount)
        let clock = ContinuousClock()

        for _ in 0..<sampleCount {
            let start = clock.now
            for _ in 0..<iterationCount {
                try! renderer.render(
                    system,
                    renderer: particleRenderer,
                    values: .init(),
                    interpolation: 0.5,
                    cullingViewProjection: matrix,
                    camera: camera
                )
            }
            samples.append(seconds(start.duration(to: clock.now)))
        }

        samples.sort()
        let elapsed = samples[sampleCount / 2]
        let nanoseconds = elapsed / Double(iterationCount) * 1_000_000_000
        let checksum = backend.checksum(particleCount: particleCount)
        print(
            "\(name), \(particleCount) particles: \(nanoseconds) ns/handoff "
                + "[\(checksum)]"
        )
    }

    @inline(__always)
    private static func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) * 1e-18
    }
}

private struct PositionBatch {
    var x: SIMD4<Float>
    var y: SIMD4<Float>
    var z: SIMD4<Float>
}

private final class BenchmarkBackend: Backend {
    private var buffers: ParticleBuffers?
    private var countAccumulator: UInt64 = 0

    func renderParticles(
        count: Int,
        buffers: ParticleBuffers,
        renderer: ParticleRenderer,
        values: ParticleRenderValues,
        interpolation: Float,
        cullingViewProjection: Matrix4x4,
        camera: CameraFrame
    ) throws {
        self.buffers = buffers
        countAccumulator &+= UInt64(count)
    }

    @inline(never)
    func checksum(particleCount: Int) -> UInt64 {
        guard let buffers else { return countAccumulator }
        let batchCount = (particleCount + 3) / 4
        return buffers.currentPositions.withUnsafeBytes { bytes in
            let positions = UnsafeBufferPointer(
                start: bytes.baseAddress?.assumingMemoryBound(
                    to: PositionBatch.self
                ),
                count: batchCount
            )
            var result = countAccumulator
            let step = max(particleCount / 64, 1)
            var index = 0
            while index < particleCount {
                let batch = positions[index / 4]
                let lane = index % 4
                result &+= UInt64(batch.x[lane].bitPattern)
                result &+= UInt64(batch.y[lane].bitPattern)
                result &+= UInt64(batch.z[lane].bitPattern)
                index += step
            }
            return result
        }
    }
}

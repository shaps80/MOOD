import PixlParticles
import Swift

@main
struct LoweringBenchmarks {
    private static let particleCounts = [
        10_000,
        50_000,
        100_000,
        250_000,
        500_000,
        1_000_000,
        2_000_000,
    ]
    private static let measuredParticleCount = 100_000_000
    private static let warmupCount = 10
    private static let sampleCount = 5

    static func main() {
        for particleCount in particleCounts {
            benchmark(particleCount: particleCount)
        }
    }

    private static func benchmark(particleCount: Int) {
        let iterationCount = max(measuredParticleCount / particleCount, 10)
        let system = System(
            seed: 0x0123456789ABCDEF,
            particleCount: particleCount,
            spawnRegion: .sphere(radius: 100),
            duration: .seconds(60)
        )
        let destination = UnsafeMutableBufferPointer<PositionPair>.allocate(
            capacity: particleCount
        )
        destination.initialize(
            repeating: PositionPair(
                previous: Position(x: 0, y: 0, z: 0),
                current: Position(x: 0, y: 0, z: 0)
            )
        )
        defer {
            destination.deinitialize()
            destination.deallocate()
        }

        let renderer = Renderer()
        for _ in 0..<warmupCount {
            _ = renderer.lowerPositionPairs(
                from: system,
                into: destination
            )
        }

        var samples: [Double] = []
        var combinedChecksum: UInt64 = 0
        samples.reserveCapacity(sampleCount)

        let clock = ContinuousClock()
        for _ in 0..<sampleCount {
            let start = clock.now
            for _ in 0..<iterationCount {
                _ = renderer.lowerPositionPairs(
                    from: system,
                    into: destination
                )
            }
            samples.append(seconds(start.duration(to: clock.now)))
            combinedChecksum ^= checksum(
                destination,
                particleCount: particleCount
            )
        }

        samples.sort()
        let elapsed = samples[sampleCount / 2]
        let loweredCount = Double(particleCount * iterationCount)
        let throughput = loweredCount / elapsed / 1_000_000
        let nanoseconds = elapsed / loweredCount * 1_000_000_000
        let milliseconds = elapsed / Double(iterationCount) * 1_000

        print(
            "\(particleCount) particles: \(throughput) million particles/s, "
                + "\(nanoseconds) ns/particle, "
                + "\(milliseconds) ms/frame [\(combinedChecksum)]"
        )
    }

    @inline(never)
    private static func checksum(
        _ positions: UnsafeMutableBufferPointer<PositionPair>,
        particleCount: Int
    ) -> UInt64 {
        var result: UInt64 = 0
        let step = particleCount / 64
        var index = 0

        while index < particleCount {
            result &+= UInt64(positions[index].previous.x.bitPattern)
            result &+= UInt64(positions[index].previous.y.bitPattern)
            result &+= UInt64(positions[index].previous.z.bitPattern)
            result &+= UInt64(positions[index].current.x.bitPattern)
            result &+= UInt64(positions[index].current.y.bitPattern)
            result &+= UInt64(positions[index].current.z.bitPattern)
            index += step
        }
        return result
    }

    @inline(__always)
    private static func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) * 1e-18
    }
}

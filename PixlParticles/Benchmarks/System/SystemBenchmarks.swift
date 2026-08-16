import Swift

@main
struct SystemBenchmarks {
    private static let seed: UInt64 = 0x0123456789ABCDEF
    private static let measuredParticleCount = 1_000_000
    private static let warmupParticleCount = 100_000
    private static let measuredTickCount = 100
    private static let warmupTickCount = 10
    private static let sampleCount = 5
    private static let fixedDelta: Float = 1.0 / 30.0
    private static let updateParticleCounts = [
        10_000,
        50_000,
        100_000,
        250_000,
        500_000,
        1_000_000,
        2_000_000,
    ]
    private static let measuredUpdateCount = 100_000_000

    static func main() {
        let regions: [(String, SpawnRegion)] = [
            ("Point", .point(.zero)),
            ("Line", .line(from: [-100, 0, 0], to: [100, 0, 0])),
            ("Cube volume", .cube(size: [200, 200, 200])),
            ("Cube surface", .cube(size: [200, 200, 200], domain: .surface)),
            ("Sphere volume", .sphere(radius: 100)),
            ("Sphere surface", .sphere(radius: 100, domain: .surface)),
        ]

        print("System initialization")

        for (name, region) in regions {
            benchmarkSpawn(name, region: region)
        }

        print("Fixed updates")
        for particleCount in updateParticleCounts {
            benchmarkUpdates(particleCount: particleCount)
        }
    }

    @_optimize(none)
    private static func benchmarkSpawn(
        _ name: String,
        region: SpawnRegion
    ) {
        let warmup = makeSystem(
            particleCount: warmupParticleCount,
            region: region
        )
        _ = checksum(warmup)

        let clock = ContinuousClock()
        var samples: [Double] = []
        var combinedChecksum: UInt64 = 0

        samples.reserveCapacity(sampleCount)

        for _ in 0..<sampleCount {
            let start = clock.now
            let system = makeSystem(
                particleCount: measuredParticleCount,
                region: region
            )
            let duration = start.duration(to: clock.now)

            combinedChecksum ^= checksum(system)
            samples.append(seconds(duration))
        }

        samples.sort()

        let elapsed = samples[sampleCount / 2]
        let particlesPerSecond = Double(measuredParticleCount) / elapsed
        let nanosecondsPerParticle = elapsed
            / Double(measuredParticleCount)
            * 1_000_000_000

        print(
            "\(name): \(particlesPerSecond / 1_000_000) million particles/s, "
                + "\(nanosecondsPerParticle) ns/particle "
                + "[\(combinedChecksum)]"
        )
    }

    @_optimize(none)
    private static func benchmarkUpdates(particleCount: Int) {
        let system = makeSystem(
            particleCount: particleCount,
            region: .point(.zero)
        )
        let measuredTickCount = max(
            measuredUpdateCount / particleCount,
            10
        )

        for _ in 0..<warmupTickCount {
            system.update(by: fixedDelta)
        }

        let clock = ContinuousClock()
        var samples: [Double] = []
        var combinedChecksum: UInt64 = 0

        samples.reserveCapacity(sampleCount)

        for _ in 0..<sampleCount {
            let start = clock.now

            for _ in 0..<measuredTickCount {
                system.update(by: fixedDelta)
            }

            let duration = start.duration(to: clock.now)
            combinedChecksum ^= checksum(system)
            samples.append(seconds(duration))
        }

        samples.sort()

        let elapsed = samples[sampleCount / 2]
        let updateCount = Double(
            particleCount * measuredTickCount
        )
        let updatesPerSecond = updateCount / elapsed
        let nanosecondsPerUpdate = elapsed / updateCount * 1_000_000_000
        let millisecondsPerTick = elapsed
            / Double(measuredTickCount)
            * 1_000

        print(
            "\(particleCount) particles: "
                + "\(updatesPerSecond / 1_000_000) million updates/s, "
                + "\(nanosecondsPerUpdate) ns/update, "
                + "\(millisecondsPerTick) ms/tick "
                + "[\(combinedChecksum)]"
        )
    }

    @inline(never)
    private static func makeSystem(
        particleCount: Int,
        region: SpawnRegion
    ) -> System {
        System(
            seed: seed,
            particleCount: particleCount,
            spawnRegion: region,
            duration: .seconds(60)
        )
    }

    @inline(never)
    private static func checksum(_ system: System) -> UInt64 {
        _ = system.sample(
            at: .now,
            isPaused: true
        )
        let particles = system.particleSnapshot
        var checksum: UInt64 = 0
        let stride = max(particles.count / 64, 1)
        var index = 0

        while index < particles.count {
            let particle = particles[index]
            checksum &+= particle.id
            checksum &+= UInt64(particle.previousPosition.x.bitPattern)
            checksum &+= UInt64(particle.previousPosition.y.bitPattern)
            checksum &+= UInt64(particle.previousPosition.z.bitPattern)
            checksum &+= UInt64(particle.position.x.bitPattern)
            checksum &+= UInt64(particle.position.y.bitPattern)
            checksum &+= UInt64(particle.position.z.bitPattern)
            checksum &+= UInt64(particle.velocity.x.bitPattern)
            checksum &+= UInt64(particle.velocity.y.bitPattern)
            checksum &+= UInt64(particle.velocity.z.bitPattern)
            index += stride
        }

        return checksum
    }

    @inline(__always)
    private static func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) * 1e-18
    }
}

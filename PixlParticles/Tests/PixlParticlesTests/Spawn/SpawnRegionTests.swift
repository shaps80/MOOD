import Testing
@testable import PixlParticles

@Suite("Spawn regions")
struct SpawnRegionTests {
    @Test("Point places every particle at one position")
    func point() {
        let position: Vec3 = [10, 20, 30]
        let particles = System(
            particleCount: 32,
            spawnRegion: .point(position)
        ).sample(at: .now).particles

        #expect(particles.allSatisfy { $0.position == position })
    }

    @Test("Line places particles uniformly between its endpoints")
    func line() {
        let particles = System(
            seed: 42,
            particleCount: 1_000,
            spawnRegion: .line(
                from: [-10, 20, 30],
                to: [10, 20, 30]
            )
        ).sample(at: .now).particles

        #expect(particles.allSatisfy { particle in
            particle.position.x >= -10 &&
                particle.position.x < 10 &&
                particle.position.y == 20 &&
                particle.position.z == 30
        })
    }

    @Test("Box fills its volume")
    func box() {
        let particles = System(
            seed: 42,
            particleCount: 1_000,
            spawnRegion: .box(size: [20, 40, 60])
        ).sample(at: .now).particles

        #expect(particles.allSatisfy { particle in
            abs(particle.position.x) <= 10 &&
                abs(particle.position.y) <= 20 &&
                abs(particle.position.z) <= 30
        })
    }

    @Test("Sphere uniformly fills its volume deterministically")
    func sphere() {
        let first = System(
            seed: 42,
            particleCount: 1_000,
            spawnRegion: .sphere(radius: 100)
        ).sample(at: .now).particles
        let second = System(
            seed: 42,
            particleCount: 1_000,
            spawnRegion: .sphere(radius: 100)
        ).sample(at: .now).particles

        #expect(first.map(\.position) == second.map(\.position))
        #expect(first.allSatisfy { particle in
            let position = particle.position
            return position.x * position.x +
                position.y * position.y +
                position.z * position.z <= 10_000
        })
        #expect(first.contains { particle in
            let position = particle.position
            return position.x * position.x +
                position.y * position.y +
                position.z * position.z < 2_500
        })
    }

    @Test("Matches stable spawn-position bit patterns")
    func stableBitPatterns() {
        let regions: [SpawnRegion] = [
            .line(from: [-10, 20, 30], to: [10, 20, 30]),
            .box(size: [20, 40, 60]),
            .sphere(radius: 100),
        ]
        let actual = regions.map { region in
            System(
                seed: 42,
                particleCount: 4,
                spawnRegion: region
            ).sample(at: .now).particles.map { particle in
                let position = particle.position
                return [
                    position.x.bitPattern,
                    position.y.bitPattern,
                    position.z.bitPattern,
                ]
            }
        }
        let expected: [[[UInt32]]] = [
            [
                [1_074_828_976, 1_101_004_800, 1_106_247_680],
                [1_092_358_634, 1_101_004_800, 1_106_247_680],
                [1_087_409_668, 1_101_004_800, 1_106_247_680],
                [1_083_371_914, 1_101_004_800, 1_106_247_680],
            ],
            [
                [1_074_828_976, 3_214_988_880, 3_251_427_658],
                [1_092_358_634, 3_235_732_452, 1_062_574_368],
                [1_087_409_668, 1_087_022_288, 1_086_670_000],
                [1_083_371_914, 1_088_056_128, 1_084_613_504],
            ],
            [
                [1_102_363_740, 3_234_401_247, 3_265_967_379],
                [3_250_952_976, 1_116_056_620, 1_097_390_144],
                [1_115_838_659, 1_107_119_621, 1_101_292_521],
                [1_110_945_260, 1_107_854_089, 1_099_578_771],
            ],
        ]

        #expect(actual == expected)
    }
}

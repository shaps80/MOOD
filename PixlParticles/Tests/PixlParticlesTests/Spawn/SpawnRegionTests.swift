import Testing
@testable import PixlParticles

@Suite("Spawn regions")
struct SpawnRegionTests {
    @Test("Point places every particle at one position")
    func point() {
        let position: Vec3 = [10, 20, 30]
        let particles = System(
            seed: 0,
            particleCount: 32,
            spawnRegion: .point(position),
            duration: .seconds(2)
        ).particleSnapshot

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
            ),
            duration: .seconds(2)
        ).particleSnapshot

        #expect(particles.allSatisfy { particle in
            particle.position.x >= -10 &&
                particle.position.x < 10 &&
                particle.position.y == 20 &&
                particle.position.z == 30
        })
    }

    @Test("Cube fills its volume")
    func cube() {
        let particles = System(
            seed: 42,
            particleCount: 1_000,
            spawnRegion: .cube(size: [20, 40, 60]),
            duration: .seconds(2)
        ).particleSnapshot

        #expect(particles.allSatisfy { particle in
            abs(particle.position.x) <= 10 &&
                abs(particle.position.y) <= 20 &&
                abs(particle.position.z) <= 30
        })
    }

    @Test("Cube surface samples faces by area deterministically")
    func cubeSurface() {
        let first = System(
            seed: 42,
            particleCount: 10_000,
            spawnRegion: .cube(
                size: [20, 40, 60],
                domain: .surface
            ),
            duration: .seconds(2)
        ).particleSnapshot
        let second = System(
            seed: 42,
            particleCount: 10_000,
            spawnRegion: .cube(
                size: [20, 40, 60],
                domain: .surface
            ),
            duration: .seconds(2)
        ).particleSnapshot

        #expect(first.map(\.position) == second.map(\.position))
        #expect(first.allSatisfy { particle in
            let position = particle.position
            return abs(position.x) == 10 ||
                abs(position.y) == 20 ||
                abs(position.z) == 30
        })

        let xFaces = first.count { abs($0.position.x) == 10 }
        let yFaces = first.count { abs($0.position.y) == 20 }
        let zFaces = first.count { abs($0.position.z) == 30 }

        #expect(xFaces > yFaces)
        #expect(yFaces > zFaces)
    }

    @Test("Cube defaults to its volume domain")
    func cubeDefaultDomain() {
        let implicit = System(
            seed: 42,
            particleCount: 1_000,
            spawnRegion: .cube(size: [20, 40, 60]),
            duration: .seconds(2)
        ).particleSnapshot
        let explicit = System(
            seed: 42,
            particleCount: 1_000,
            spawnRegion: .cube(
                size: [20, 40, 60],
                domain: .volume
            ),
            duration: .seconds(2)
        ).particleSnapshot

        #expect(implicit.map(\.position) == explicit.map(\.position))
    }

    @Test("Sphere uniformly fills its volume deterministically")
    func sphere() {
        let first = System(
            seed: 42,
            particleCount: 1_000,
            spawnRegion: .sphere(radius: 100),
            duration: .seconds(2)
        ).particleSnapshot
        let second = System(
            seed: 42,
            particleCount: 1_000,
            spawnRegion: .sphere(radius: 100),
            duration: .seconds(2)
        ).particleSnapshot

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

    @Test("Sphere surface samples its radius deterministically")
    func sphereSurface() {
        let first = System(
            seed: 42,
            particleCount: 10_000,
            spawnRegion: .sphere(radius: 100, domain: .surface),
            duration: .seconds(2)
        ).particleSnapshot
        let second = System(
            seed: 42,
            particleCount: 10_000,
            spawnRegion: .sphere(radius: 100, domain: .surface),
            duration: .seconds(2)
        ).particleSnapshot

        #expect(first.map(\.position) == second.map(\.position))
        #expect(first.allSatisfy { particle in
            let position = particle.position
            let radiusSquared = position.x * position.x +
                position.y * position.y +
                position.z * position.z
            return abs(radiusSquared - 10_000) < 0.01
        })
    }

    @Test("Matches stable spawn-position bit patterns")
    func stableBitPatterns() {
        let regions: [SpawnRegion] = [
            .line(from: [-10, 20, 30], to: [10, 20, 30]),
            .cube(size: [20, 40, 60]),
            .cube(size: [20, 40, 60], domain: .surface),
            .sphere(radius: 100),
            .sphere(radius: 100, domain: .surface),
        ]
        let actual = regions.map { region in
            System(
                seed: 42,
                particleCount: 4,
                spawnRegion: region,
                duration: .seconds(2)
            ).particleSnapshot.map { particle in
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
                [1_092_616_192, 3_214_988_880, 3_251_427_658],
                [1_092_616_192, 3_235_732_452, 1_062_574_368],
                [1_092_616_192, 1_087_022_288, 1_086_670_000],
                [1_092_616_192, 1_088_056_128, 1_084_613_504],
            ],
            [
                [1_102_363_740, 3_234_401_247, 3_265_967_379],
                [3_250_952_976, 1_116_056_620, 1_097_390_144],
                [1_115_838_659, 1_107_119_621, 1_101_292_521],
                [1_110_945_260, 1_107_854_089, 1_099_578_771],
            ],
            [
                [1_110_422_093, 3_242_422_486, 1_118_962_006],
                [3_266_409_025, 3_255_413_204, 3_254_109_107],
                [1_119_070_998, 1_110_348_665, 3_231_716_222],
                [1_117_169_044, 1_113_582_701, 1_107_960_267],
            ],
        ]

        #expect(actual == expected)
    }
}

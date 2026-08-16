import Testing
@testable import PixlParticles
@testable import PixlRenderer

@Suite("Renderer lowering")
struct RendererTests {
    @Test("Writes interpolated positions directly into caller storage")
    func positions() {
        let system = System(
            seed: 42,
            particleCount: 5,
            spawnRegion: .point([1, 2, 3]),
            duration: .seconds(1)
        )
        let start = ContinuousClock.now
        _ = system.sample(at: start)
        let sample = system.sample(
            at: start.advanced(by: .milliseconds(50))
        )
        let destination = UnsafeMutableBufferPointer<Position>.allocate(
            capacity: 5
        )
        destination.initialize(
            repeating: Position(x: 0, y: 0, z: 0)
        )
        defer {
            destination.deinitialize()
            destination.deallocate()
        }

        let count = Renderer().lowerPositions(
            from: system,
            interpolation: sample.interpolation,
            into: destination
        )

        let particles = system.particleSnapshot
        #expect(count == particles.count)
        for index in 0..<count {
            let expected = particles[index].interpolated(
                by: sample.interpolation
            )
            #expect(destination[index].x == expected.x)
            #expect(destination[index].y == expected.y)
            #expect(destination[index].z == expected.z)
        }
    }
}

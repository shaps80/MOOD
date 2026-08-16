import Testing
@testable import PixlParticles
@testable import PixlRenderer

@Suite("Renderer lowering")
struct RendererTests {
    @Test("Writes previous and current positions into caller storage")
    func positions() {
        let system = System(
            seed: 42,
            particleCount: 5,
            spawnRegion: .point([1, 2, 3]),
            duration: .seconds(1)
        )
        let start = ContinuousClock.now
        _ = system.sample(at: start)
        _ = system.sample(
            at: start.advanced(by: .milliseconds(50))
        )
        let destination = UnsafeMutableBufferPointer<PositionPair>.allocate(
            capacity: 5
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

        let count = Renderer().lowerPositionPairs(
            from: system,
            into: destination
        )

        let particles = system.particleSnapshot
        #expect(count == particles.count)
        for index in 0..<count {
            let pair = destination[index]
            #expect(pair.previous.x == particles[index].previousPosition.x)
            #expect(pair.previous.y == particles[index].previousPosition.y)
            #expect(pair.previous.z == particles[index].previousPosition.z)
            #expect(pair.current.x == particles[index].position.x)
            #expect(pair.current.y == particles[index].position.y)
            #expect(pair.current.z == particles[index].position.z)
        }
    }
}

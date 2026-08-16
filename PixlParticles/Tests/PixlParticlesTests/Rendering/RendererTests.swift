import PixlRenderer
import Testing
@testable import PixlParticles

@MainActor
@Suite("Particle rendering boundary")
struct ParticleRendererTests {
    @Test("Pushes changed positions directly into backend storage")
    func writesOnlyChangedPositions() throws {
        let backend = RecordingBackend(capacity: 5)
        let renderer = PixlParticles.Renderer(backend: backend)
        let system = System(
            seed: 42,
            particleCount: 5,
            spawnRegion: .point([1, 2, 3]),
            duration: .seconds(1)
        )

        try renderer.render(
            system,
            interpolation: 0,
            tick: 0,
            viewProjection: .identity
        )
        try renderer.render(
            system,
            interpolation: 0.5,
            tick: 0,
            viewProjection: .identity
        )
        try renderer.render(
            system,
            interpolation: 0,
            tick: 1,
            viewProjection: .identity
        )

        #expect(backend.renderCount == 3)
        #expect(backend.writeCount == 2)
        #expect(backend.positions[0].current == Position(x: 1, y: 2, z: 3))
    }
}

@MainActor
private final class RecordingBackend: Backend {
    let positions: UnsafeMutableBufferPointer<PositionPair>
    private(set) var renderCount = 0
    private(set) var writeCount = 0

    init(capacity: Int) {
        positions = .allocate(capacity: capacity)
        positions.initialize(
            repeating: .init(
                previous: .init(x: 0, y: 0, z: 0),
                current: .init(x: 0, y: 0, z: 0)
            )
        )
    }

    isolated deinit {
        positions.deinitialize()
        positions.deallocate()
    }

    func renderPoints(
        count: Int,
        positionsChanged: Bool,
        interpolation: Float,
        viewProjection: Matrix4x4,
        writePositions: (UnsafeMutableBufferPointer<PositionPair>) -> Void
    ) throws {
        renderCount += 1
        if positionsChanged {
            writeCount += 1
            writePositions(.init(rebasing: positions[..<count]))
        }
    }
}

private extension Matrix4x4 {
    static let identity = Matrix4x4(
        x: [1, 0, 0, 0],
        y: [0, 1, 0, 0],
        z: [0, 0, 1, 0],
        w: [0, 0, 0, 1]
    )
}

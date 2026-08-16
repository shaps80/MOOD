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
            viewProjection: .identity,
            viewport: .init(width: 100, height: 100)
        )
        try renderer.render(
            system,
            interpolation: 0.5,
            tick: 0,
            viewProjection: .identity,
            viewport: .init(width: 100, height: 100)
        )
        try renderer.render(
            system,
            interpolation: 0,
            tick: 1,
            viewProjection: .identity,
            viewport: .init(width: 100, height: 100)
        )

        #expect(backend.renderCount == 3)
        #expect(backend.writeCount == 2)
        #expect(backend.idWriteCount == 1)
        #expect(backend.ids[4] == 4)
        #expect(backend.positions[0].current == Position(x: 1, y: 2, z: 3))
    }
}

private final class RecordingBackend: Backend {
    let positions: UnsafeMutableBufferPointer<PositionPair>
    let ids: UnsafeMutableBufferPointer<UInt64>
    private(set) var renderCount = 0
    private(set) var writeCount = 0
    private(set) var idWriteCount = 0

    init(capacity: Int) {
        positions = .allocate(capacity: capacity)
        positions.initialize(
            repeating: .init(
                previous: .init(x: 0, y: 0, z: 0),
                current: .init(x: 0, y: 0, z: 0)
            )
        )
        ids = .allocate(capacity: capacity)
        ids.initialize(repeating: 0)
    }

    deinit {
        positions.deinitialize()
        positions.deallocate()
        ids.deinitialize()
        ids.deallocate()
    }

    func renderPoints(
        count: Int,
        positionsChanged: Bool,
        idsChanged: Bool,
        interpolation: Float,
        viewProjection: Matrix4x4,
        viewport: ViewportSize,
        writePositions: (UnsafeMutableBufferPointer<PositionPair>) -> Void,
        writeIDs: (UnsafeMutableBufferPointer<UInt64>) -> Void
    ) throws {
        renderCount += 1
        if positionsChanged {
            writeCount += 1
            writePositions(.init(rebasing: positions[..<count]))
        }
        if idsChanged {
            idWriteCount += 1
            writeIDs(.init(rebasing: ids[..<count]))
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

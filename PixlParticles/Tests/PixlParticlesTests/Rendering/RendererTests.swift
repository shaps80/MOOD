import PixlRenderer
import Testing
@testable import PixlParticles

@MainActor
@Suite("Particle rendering boundary")
struct ParticleRendererTests {
    @Test("Shares authoritative AoSoA storage with the backend")
    func sharesStorage() throws {
        let backend = RecordingBackend()
        let renderer = PixlParticles.Renderer(backend: backend)
        let system = System(
            seed: 42,
            particleCount: 5,
            spawnRegion: .point([1, 2, 3]),
            color: .init(red: 2, green: 1, blue: 0.5, alpha: 0.5),
            duration: .seconds(1)
        )

        try renderer.render(
            system,
            interpolation: 0,
            cullingViewProjection: .identity,
            viewProjection: .identity,
            viewport: .init(width: 100, height: 100)
        )
        let first = try #require(backend.buffers)

        try renderer.render(
            system,
            interpolation: 0.5,
            cullingViewProjection: .identity,
            viewProjection: .identity,
            viewport: .init(width: 100, height: 100)
        )
        let second = try #require(backend.buffers)

        system.update(by: 1)
        try renderer.render(
            system,
            interpolation: 0.5,
            cullingViewProjection: .identity,
            viewProjection: .identity,
            viewport: .init(width: 100, height: 100)
        )
        let third = try #require(backend.buffers)

        #expect(backend.renderCount == 3)
        #expect(first.currentPositions === second.currentPositions)
        #expect(first.colors === second.colors)
        #expect(first.currentPositions === third.previousPositions)
        #expect(first.previousPositions === third.currentPositions)
        #expect(first.colors === third.colors)

        let positions = first.currentPositions.mutableBuffer(
            of: TestPositionBatch.self,
            count: 2
        )
        let colors = first.colors.mutableBuffer(
            of: TestColorBatch.self,
            count: 2
        )
        let ids = first.ids.mutableBuffer(
            of: SIMD4<UInt64>.self,
            count: 2
        )
        #expect(positions[0].x[0] == 1)
        #expect(positions[0].y[0] == 2)
        #expect(positions[0].z[0] == 3)
        #expect(colors[0].red[0] == 1)
        #expect(colors[0].green[0] == 0.5)
        #expect(colors[0].blue[0] == 0.25)
        #expect(colors[0].alpha[0] == 0.5)
        #expect(ids[1][0] == 4)
    }
}

private struct TestPositionBatch {
    var x: SIMD4<Float>
    var y: SIMD4<Float>
    var z: SIMD4<Float>
}

private struct TestColorBatch {
    var red: SIMD4<Float>
    var green: SIMD4<Float>
    var blue: SIMD4<Float>
    var alpha: SIMD4<Float>
}

private final class RecordingBackend: Backend {
    private(set) var buffers: PointBuffers?
    private(set) var renderCount = 0

    func renderPoints(
        count: Int,
        buffers: PointBuffers,
        interpolation: Float,
        cullingViewProjection: Matrix4x4,
        viewProjection: Matrix4x4,
        viewport: ViewportSize
    ) throws {
        renderCount += 1
        self.buffers = buffers
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

import Pixl
import Pixl2D

@main
struct Game: Pixl.Game {
    private final class State: @unchecked Sendable {
        var rotation: Double = 0
        var previousRotation: Double = 0
        var metricsElapsed = 0.0
    }

    private struct Vertex {
        let position: SIMD2<Float>
        let color: SIMD4<Float>
    }

    private struct Triangle {
        let first: Vertex
        let second: Vertex
        let third: Vertex
    }

    private let vertexBuffer: Buffer
    private let pipeline: RenderPipeline
    private let state = State()
    private let camera = OrthographicCamera(halfHeight: 1)

    static var gameSettings: GameSettings {
        .init(
            title: "Pixl",
            resolution: .init(
                width: 800,
                height: 400
            )
        )
    }

    func update(_ time: UpdateTime, lanes: Lanes) {
        state.rotation = time.elapsedSeconds
    }

    init(platform: any Platform) throws {
        var triangle = Triangle(
            first: .init(position: .init(0, 0.5), color: .init(1, 0, 0, 1)),
            second: .init(position: .init(-0.5, -0.5), color: .init(0, 1, 0, 1)),
            third: .init(position: .init(0.5, -0.5), color: .init(0, 0, 1, 1))
        )

        vertexBuffer = try withUnsafeBytes(of: &triangle) {
            try platform.device.makeBuffer(
                copying: $0,
                usage: .vertex,
                memory: .gpuOnly
            )
        }

        let vertexLayout = VertexLayout(bufferCapacity: 1, attributeCapacity: 2)
        vertexLayout.append(
            .init(
                bufferIndex: 0,
                stride: UInt64(MemoryLayout<Vertex>.stride)
            )
        )

        vertexLayout.append(
            .init(
                location: 0,
                bufferIndex: 0,
                format: .float32x2,
                offset: 0
            )
        )

        vertexLayout.append(
            .init(
                location: 1,
                bufferIndex: 0,
                format: .float32x4,
                offset: UInt64(MemoryLayout<Vertex>.offset(of: \.color)!)
            )
        )

        pipeline = try platform.device.makeRenderPipeline(
            .init(
                vertex: Shaders.vertex,
                fragment: Shaders.fragment,
                vertexLayout: vertexLayout,
                colorFormat: Self.renderSettings.drawableFormat
            )
        )
    }

    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame,
        time: RenderTime
    ) throws {
        let pass = frame.beginRenderPass(
            RenderPassDescriptor(
                ColorAttachment(
                    target: output,
                    loadAction: .clear(.black)
                )
            )
        )
        pass.setRenderPipeline(pipeline)
        pass.setVertexBuffer(vertexBuffer, index: 0)
        pass.setVertexBytes(
            of: camera.projection(for: output).rotated(by: state.rotation),
            index: 1
        )
        pass.drawPrimitives(.triangle, vertexCount: 3)

        logMetrics(metrics: time.metrics)
    }

    private func logMetrics(metrics: PerformanceMetrics) {
        state.metricsElapsed += metrics.frameTimeSeconds
        guard state.metricsElapsed >= 5 else { return }
        state.metricsElapsed.formTruncatingRemainder(dividingBy: 5)
        print(metrics.summary)
    }
}

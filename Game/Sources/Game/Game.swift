import Pixl
import Pixl2D

@main
struct Game: Pixl.Game {
    private final class State: @unchecked Sendable {
        var rotation: Double = 0
        var previousRotation: Double = 0
        var metricsElapsed = 0.0
    }

    private let triangle: Triangle
    private let quad: Quad
    private let pipeline: RenderPipeline
    private let state = State()
    private let camera = OrthographicCamera()

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
        triangle = try Triangle(
            device: platform.device,
            colors: (
                .red,
                .init(red: 0, green: 1, blue: 0),
                .init(red: 0, green: 0, blue: 1)
            )
        )
        quad = try Quad(
            device: platform.device,
            colors: (
                .init(red: 1, green: 1, blue: 0),
                .init(red: 0, green: 1, blue: 1),
                .init(red: 1, green: 0, blue: 1),
                .white
            )
        )

        pipeline = try platform.device.makeRenderPipeline(
            .init(
                vertex: Shaders.vertex,
                fragment: Shaders.fragment,
                vertexLayout: Triangle.makeVertexLayout(),
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
        pass.setVertexBytes(
            of: camera.projection(for: output)
                .translated(by: .init(x: -0.75, y: 0))
                .rotated(by: state.rotation),
            index: 1
        )
        triangle.draw(on: pass)
        pass.setVertexBytes(
            of: camera.projection(for: output)
                .translated(by: .init(x: 0.75, y: 0))
                .rotated(by: -state.rotation),
            index: 1
        )
        quad.draw(on: pass)

        logMetrics(metrics: time.metrics)
    }

    private func logMetrics(metrics: PerformanceMetrics) {
        state.metricsElapsed += metrics.frameTimeSeconds
        guard state.metricsElapsed >= 5 else { return }
        state.metricsElapsed.formTruncatingRemainder(dividingBy: 5)
        print(metrics.summary)
    }
}

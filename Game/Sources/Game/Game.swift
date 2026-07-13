import Pixl
import Pixl2D

@main
struct Game: Pixl.Game {
    private final class State: @unchecked Sendable {
        var angle: Angle = .zero
        var metricsElapsed = 0.0
    }

    private let state = State()
    private let triangle: Triangle
    private let quad: Quad
    private let pipeline: RenderPipeline
    private let camera = OrthographicCamera()

    static let gameSettings: GameSettings = .init(
        title: "Pixl",
        resolution: .init(
            width: 800,
            height: 400
        )
    )

    func update(_ time: UpdateTime, lanes: Lanes) {
        state.angle = .radians(time.elapsedSeconds)
    }

    init(platform: any Platform) throws {
        triangle = try Triangle(device: platform.device)
        quad = try Quad(device: platform.device)

        pipeline = try platform.device.makeRenderPipeline(
            .init(
                vertex: Shaders.vertex,
                fragment: Shaders.fragment,
                vertexLayout: ColorGeometry.vertexLayout,
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
        let pass = frame.clear(target: output)
        pass.setRenderPipeline(pipeline)

        triangle.draw(
            on: pass,
            transform: camera.projection(for: output)
                .translated(by: .init(x: -0.75, y: 0))
                .rotated(by: state.angle.radians)
        )

        quad.draw(
            on: pass,
            transform: camera.projection(for: output)
                .translated(by: .init(x: 0.75, y: 0))
                .rotated(by: -state.angle.radians)
        )

        logMetrics(metrics: time.metrics)
    }

    private func logMetrics(metrics: PerformanceMetrics) {
        state.metricsElapsed += metrics.frameTimeSeconds
        guard state.metricsElapsed >= 5 else { return }
        state.metricsElapsed.formTruncatingRemainder(dividingBy: 5)
        print(metrics.summary)
    }
}

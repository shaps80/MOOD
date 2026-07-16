import Pixl
import Pixl2D

struct Player: Entity {
    private let triangle: Triangle
    private let pipeline: RenderPipeline

    private let camera = OrthographicCamera(halfHeight: 1)
    private var rotation: Double = .zero
    private let position = Vec2.zero

    init(
        pipeline: RenderPipeline,
        context: GameContext
    ) throws {
        self.triangle = try .init(device: context.platform.device)
        self.pipeline = pipeline
    }

    mutating func update(_ time: UpdateTime, lanes: Lanes) {
        rotation = time.elapsedSeconds
    }

    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame,
        time: RenderTime
    ) throws {
        let pass = frame.beginRenderPass(
            .init(.init(target: output, loadAction: .load))
        )

        pass.setRenderPipeline(pipeline)
        triangle.draw(
            on: pass,
            transform: camera
                .projection(for: output)
                .translated(by: position)
                .rotated(by: rotation)
        )
    }
}

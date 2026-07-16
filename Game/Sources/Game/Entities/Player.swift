import Pixl
import Pixl2D

struct Player: Entity {
    private let quad: Quad
    private let pipeline: RenderPipeline
    private let sampler: Sampler
    private let texture: TextureAsset

    private let camera = OrthographicCamera(halfHeight: 1)
    private var rotation: Double = .zero
    private let position = Vec2.zero

    init(
        pipeline: RenderPipeline,
        context: GameContext
    ) throws {
        quad = try .init(
            device: context.platform.device,
            color: .white
        )
        self.pipeline = pipeline
        sampler = try context.platform.device.makeSampler(.init())
        texture = try context.assets.load(texture: "player.png")
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
        pass.setFragmentTexture(texture, index: 0)
        pass.setFragmentSampler(sampler, index: 0)
        quad.draw(
            on: pass,
            transform: camera
                .projection(for: output)
                .translated(by: position)
                .rotated(by: rotation)
        )
    }
}

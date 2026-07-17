import Pixl
import Pixl2D

struct Player: Entity {
    private let pipeline: RenderPipeline
    
    private let quad: Quad
    private let texture: TextureAsset
    private let sampler: Sampler

    private let camera = OrthographicCamera(halfHeight: 1)
    private let position = Vec2.zero

    init(
        pipeline: RenderPipeline,
        audio: GameAudio,
        context: GameContext
    ) throws {
        texture = try context.assets.load(texture: "player.png")
        quad = try .init(
            device: context.platform.device,
            color: .clear
        )

        self.pipeline = pipeline
        self.sampler = try context.platform.device.makeSampler(.init())
    }

    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame,
        time: RenderTime,
        context: GameContext
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
        )
    }
}

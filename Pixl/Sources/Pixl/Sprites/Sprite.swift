import Pixl2D
import PixlPlatform

public struct Sprite {
    private let pipeline: RenderPipeline
    private let quad: Quad
    private let texture: TextureAsset
    private let sampler: Sampler

    public init(named name: String, pipeline: RenderPipeline, context: GameContext) throws {
        self.pipeline = pipeline
        texture = try context.assets.load(texture: name)
        quad = try .init(
            device: context.platform.device,
            color: .clear
        )
        sampler = try context.platform.device.makeSampler(.init())
    }

    public func draw(frame: borrowing Frame, output: RenderTarget, transform: Transform2D) {
        let pass = frame.beginRenderPass(
            .init(.init(target: output, loadAction: .load))
        )

        pass.setRenderPipeline(pipeline)
        pass.setFragmentTexture(texture, index: 0)
        pass.setFragmentSampler(sampler, index: 0)
        quad.draw(
            on: pass,
            transform: transform
        )
    }
}

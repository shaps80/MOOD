import Pixl2D
import PixlPlatform

public struct Sprite {
    private let pipeline: RenderPipeline
    private let quad: Quad
    public let asset: TextureAsset
    private let sampler: Sampler
    public var isFlipped: Bool = false

    public init(named name: String, pipeline: RenderPipeline, context: GameContext) throws {
        self.pipeline = pipeline
        asset = try context.assets.load(texture: name)
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
        let size = asset.texture.descriptor.size
        let width = Double(size.width) * (isFlipped ? -1 : 1)
        let height = Double(size.height)

        pass.setRenderPipeline(pipeline)
        pass.setFragmentTexture(asset, index: 0)
        pass.setFragmentSampler(sampler, index: 0)
        quad.draw(
            on: pass,
            transform: transform
                .scaled(
                    x: .init(width),
                    y: .init(height)
                )
        )
    }
}

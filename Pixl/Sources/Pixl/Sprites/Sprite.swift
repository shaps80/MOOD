import Pixl2D
import PixlPlatform

public struct Sprite {
    private let pipeline: RenderPipeline
    private let quad: Quad
    private let sampler: Sampler
    public var region: TextureRegion
    public var isFlipped: Bool = false

    public var asset: TextureAsset {
        region.asset
    }

    public init(named name: String, pipeline: RenderPipeline, context: GameContext) throws {
        self.pipeline = pipeline
        let asset = try context.assets.load(texture: name)
        region = TextureRegion(asset: asset)
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
        let width = region.source.size.x * (isFlipped ? -1 : 1)
        let height = region.source.size.y

        pass.setRenderPipeline(pipeline)
        pass.setFragmentTexture(region.asset, index: 0)
        pass.setFragmentSampler(sampler, index: 0)
        quad.draw(
            on: pass,
            transform: transform
                .scaled(
                    x: .init(width),
                    y: .init(height)
                ),
            textureCoordinates: region.textureCoordinates
        )
    }
}

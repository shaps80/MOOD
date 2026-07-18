import Pixl2D
import PixlPlatform

/// Shared GPU state used to record sprites into caller-owned render passes.
public struct SpriteRenderer {
    private let pipeline: RenderPipeline
    private let quad: Quad
    private let sampler: Sampler

    public init(context: GameContext) throws {
        try self.init(
            device: context.platform.device,
            colorFormat: context.drawableFormat
        )
    }

    public init(device: any Device, colorFormat: PixelFormat) throws {
        pipeline = try device.makeRenderPipeline(
            .init(
                vertex: .vertex,
                fragment: .fragment,
                vertexLayout: .primitive,
                colorFormat: colorFormat
            )
        )
        quad = try .init(device: device, color: .clear)
        sampler = try device.makeSampler(.init())
    }

    /// Records one sprite into an existing render pass.
    public func draw(
        _ sprite: Sprite,
        on pass: RenderPassEncoder,
        transform: Transform2D
    ) {
        let width = sprite.region.source.size.x
            * (sprite.isFlipped ? -1 : 1)
        let height = sprite.region.source.size.y

        pass.setRenderPipeline(pipeline)
        pass.setFragmentTexture(sprite.region.asset, index: 0)
        pass.setFragmentSampler(sampler, index: 0)
        quad.draw(
            on: pass,
            transform: transform.scaled(x: width, y: height),
            textureCoordinates: sprite.region.textureCoordinates
        )
    }
}

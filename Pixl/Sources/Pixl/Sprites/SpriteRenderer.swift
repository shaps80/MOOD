import Pixl2D
import PixlPlatform

/// Shared GPU state and retained frame submissions for ordered sprite drawing.
public final class SpriteRenderer {
    private let pipeline: RenderPipeline
    private let quad: Quad
    private let sampler: Sampler
    private var submissions: ContiguousArray<SpriteSubmission> = []
    private var layersAreOrdered = true
    private var lastLayer: RenderLayer?

    public convenience init(
        context: GameContext,
        minimumCapacity: Int = 1_024
    ) throws {
        try self.init(
            device: context.platform.device,
            colorFormat: context.drawableFormat,
            minimumCapacity: minimumCapacity
        )
    }

    public init(
        device: any Device,
        colorFormat: PixelFormat,
        minimumCapacity: Int = 1_024
    ) throws {
        precondition(
            minimumCapacity >= 0,
            "Sprite renderer minimum capacity must be nonnegative"
        )
        pipeline = try device.makeRenderPipeline(
            .init(
                vertex: .vertex,
                fragment: .fragment,
                vertexLayout: .primitive,
                colorFormat: colorFormat,
                blendMode: .normal
            )
        )
        quad = try .init(device: device, color: .white)
        sampler = try device.makeSampler(.init())
        submissions.reserveCapacity(minimumCapacity)
    }

    /// Reserves retained CPU submission storage without imposing a hard limit.
    public func reserveCapacity(_ minimumCapacity: Int) {
        precondition(
            minimumCapacity >= 0,
            "Sprite renderer minimum capacity must be nonnegative"
        )
        submissions.reserveCapacity(minimumCapacity)
    }

    /// Resolves and appends one sprite for the next render call.
    public func submit(
        _ sprite: Sprite,
        transform: Transform2D
    ) {
        let width = sprite.region.source.size.x
            * (sprite.isFlipped ? -1 : 1)
        let height = sprite.region.source.size.y
        let order = SpriteSubmissionOrder(
            layer: sprite.layer,
            ordinal: submissions.count
        )

        if let lastLayer, sprite.layer < lastLayer {
            layersAreOrdered = false
        }
        lastLayer = sprite.layer

        submissions.append(
            SpriteSubmission(
                order: order,
                asset: sprite.region.asset,
                textureCoordinates: sprite.region.textureCoordinates,
                transform: transform.scaled(x: width, y: height)
            )
        )
    }

    /// Orders pending sprites and records them into an existing render pass.
    public func render(on pass: RenderPassEncoder) {
        defer {
            submissions.removeAll(keepingCapacity: true)
            layersAreOrdered = true
            lastLayer = nil
        }

        if !layersAreOrdered {
            submissions.sort { $0.order < $1.order }
        }

        for submission in submissions {
            pass.setRenderPipeline(pipeline)
            pass.setFragmentTexture(submission.asset, index: 0)
            pass.setFragmentSampler(sampler, index: 0)
            quad.draw(
                on: pass,
                transform: submission.transform,
                textureCoordinates: submission.textureCoordinates
            )
        }
    }
}

struct SpriteSubmissionOrder: Comparable {
    let layer: RenderLayer
    let ordinal: Int

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.layer != rhs.layer {
            return lhs.layer < rhs.layer
        }
        return lhs.ordinal < rhs.ordinal
    }
}

private struct SpriteSubmission {
    let order: SpriteSubmissionOrder
    let asset: TextureAsset
    let textureCoordinates: TextureCoordinates
    let transform: Transform2D
}

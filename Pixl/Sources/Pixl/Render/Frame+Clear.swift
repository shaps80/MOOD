import PixlGraphics
import PixlPlatform

public extension Frame {
    /// Begins a render pass that clears a target before drawing.
    /// - Parameters:
    ///   - color: Clear colour. Defaults to opaque black.
    ///   - target: Texture subresource cleared and rendered into.
    /// - Returns: Encoder for recording commands into the new pass.
    func clear(
        _ color: PixlGraphics.Color = .init(0, 0, 0, 1),
        target: RenderTarget
    ) -> RenderPassEncoder {
        beginRenderPass(
            RenderPassDescriptor(
                ColorAttachment(
                    target: target,
                    loadAction: .clear(color)
                )
            )
        )
    }
}

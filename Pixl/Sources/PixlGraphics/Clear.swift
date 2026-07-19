import PixlPlatform

extension Frame {
    public func clear(_ color: Color = .black, target: RenderTarget) -> RenderPassEncoder {
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

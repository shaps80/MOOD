import PixlPlatform

public extension Frame {
    func clear(_ color: Color = .black, target: RenderTarget) -> RenderPassEncoder {
        beginRenderPass(
            RenderPassDescriptor(
                ColorAttachment(
                    target: target,
                    loadAction: .clear(.black)
                )
            )
        )
    }
}

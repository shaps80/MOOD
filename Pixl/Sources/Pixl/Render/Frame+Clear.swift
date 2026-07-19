import PixlGraphics
import PixlPlatform

public extension Frame {
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

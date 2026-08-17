import Metal
import PixlRenderer

final class MetalCommandBuffer: PixlRenderer.CommandBuffer {
    let value: any MTLCommandBuffer

    var label: String? {
        get { value.label }
        set { value.label = newValue }
    }

    init(_ value: any MTLCommandBuffer) { self.value = value }

    func makeComputeEncoder() -> (any PixlRenderer.ComputeEncoder)? {
        value.makeComputeCommandEncoder().map(MetalComputeEncoder.init)
    }

    func makeRenderEncoder(
        target: any PixlRenderer.RenderTarget
    ) -> (any PixlRenderer.RenderEncoder)? {
        guard let target = target as? MetalRenderTarget else {
            preconditionFailure("Render target belongs to another platform")
        }
        return value.makeRenderCommandEncoder(descriptor: target.descriptor)
            .map(MetalRenderEncoder.init)
    }

    func present(_ target: any PixlRenderer.RenderTarget) {
        guard let target = target as? MetalRenderTarget else {
            preconditionFailure("Render target belongs to another platform")
        }
        value.present(target.drawable)
    }

    func addCompletedHandler(
        _ handler: @escaping @Sendable (_ gpuDuration: Double?) -> Void
    ) {
        value.addCompletedHandler { commandBuffer in
            let duration = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
            handler(duration > 0 ? duration : nil)
        }
    }
}

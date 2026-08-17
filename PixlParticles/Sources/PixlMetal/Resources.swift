import Metal
import PixlRenderer
import Swift

final class MetalBuffer: PixlRenderer.Buffer {
    let value: any MTLBuffer
    var length: Int { value.length }

    init(_ value: any MTLBuffer) { self.value = value }

    func withMutableBytes(
        _ body: (UnsafeMutableRawBufferPointer) -> Void
    ) {
        precondition(value.storageMode == .shared)
        body(.init(start: value.contents(), count: value.length))
    }
}

final class MetalComputePipeline: PixlRenderer.ComputePipeline {
    let value: any MTLComputePipelineState
    init(_ value: any MTLComputePipelineState) { self.value = value }
}

final class MetalRenderPipeline: PixlRenderer.RenderPipeline {
    let value: any MTLRenderPipelineState
    init(_ value: any MTLRenderPipelineState) { self.value = value }
}

final class MetalDepthState: PixlRenderer.DepthState {
    let value: any MTLDepthStencilState
    init(_ value: any MTLDepthStencilState) { self.value = value }
}

final class MetalRenderTarget: PixlRenderer.RenderTarget {
    let descriptor: MTLRenderPassDescriptor
    let drawable: any MTLDrawable

    init(descriptor: MTLRenderPassDescriptor, drawable: any MTLDrawable) {
        self.descriptor = descriptor
        self.drawable = drawable
    }

    func addPresentedHandler(
        _ handler: @escaping @Sendable (_ presentationTime: Double) -> Void
    ) {
        drawable.addPresentedHandler { drawable in
            handler(drawable.presentedTime)
        }
    }
}

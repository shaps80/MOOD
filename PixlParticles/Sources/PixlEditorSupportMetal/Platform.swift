import Metal
import PixlMetal
import PixlRenderer

public final class Platform: PixlRenderer.Platform {
    private let base: PixlMetal.Platform
    private let library: any MTLLibrary

    public init(base: PixlMetal.Platform, device: any MTLDevice) throws {
        guard let library = try? device.makeDefaultLibrary(bundle: .module) else {
            throw PlatformError.shaderLibrary
        }
        self.base = base
        self.library = library
    }

    public func acquireFrame() { base.acquireFrame() }
    public func releaseFrame() { base.releaseFrame() }

    public func submit(_ commandBuffer: any CommandBuffer) {
        base.submit(commandBuffer)
    }

    public func makeBuffer(
        length: Int,
        memory: BufferMemory
    ) -> (any Buffer)? {
        base.makeBuffer(length: length, memory: memory)
    }

    public func makeBuffer(sharing storage: HostBuffer) -> (any Buffer)? {
        base.makeBuffer(sharing: storage)
    }

    public func makeComputePipeline(
        function: String
    ) -> (any ComputePipeline)? {
        base.makeComputePipeline(function: function)
    }

    public func makeRenderPipeline(
        _ descriptor: RenderPipelineDescriptor
    ) -> (any RenderPipeline)? {
        base.makeRenderPipeline(descriptor, library: library)
            ?? base.makeRenderPipeline(descriptor)
    }

    public func makeDepthState(
        compare: CompareFunction,
        isWriteEnabled: Bool
    ) -> (any DepthState)? {
        base.makeDepthState(
            compare: compare,
            isWriteEnabled: isWriteEnabled
        )
    }

    public func makeCommandBuffer() -> (any CommandBuffer)? {
        base.makeCommandBuffer()
    }

    public func currentRenderTarget() -> (any RenderTarget)? {
        base.currentRenderTarget()
    }
}

private enum PlatformError: Error {
    case shaderLibrary
}

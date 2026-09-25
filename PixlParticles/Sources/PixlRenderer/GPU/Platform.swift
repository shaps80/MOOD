import Swift

public protocol Platform: AnyObject {
    /// 64-bit atomic minimum in compute buffers and fragment-buffer reads.
    var supportsAtomicUInt64Min: Bool { get }
    func acquireFrame()
    func releaseFrame()
    func submit(_ commandBuffer: any CommandBuffer)
    func makeBuffer(
        length: Int,
        memory: BufferMemory
    ) -> (any Buffer)?
    func makeBuffer(
        sharing storage: HostBuffer
    ) -> (any Buffer)?
    func makeComputePipeline(
        function: String
    ) -> (any ComputePipeline)?
    func makeRenderPipeline(
        _ descriptor: RenderPipelineDescriptor
    ) -> (any RenderPipeline)?
    func makeDepthState(
        compare: CompareFunction,
        isWriteEnabled: Bool
    ) -> (any DepthState)?
    func makeCommandBuffer() -> (any CommandBuffer)?
    func currentRenderTarget() -> (any RenderTarget)?
}

public extension Platform {
    var supportsAtomicUInt64Min: Bool { false }
}

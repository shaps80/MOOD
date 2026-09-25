import PixlRenderer
import PixlMetal

/// Uses production resources, encoders, shaders and counters; omits window presentation.
final class BenchmarkPlatform: PixlRenderer.Platform {
    public var supportsAtomicUInt64Min: Bool { usesCompute && base.supportsAtomicUInt64Min }
    private let usesCompute: Bool
    let base: PixlMetal.Platform
    init(base: PixlMetal.Platform, usesCompute: Bool = true) {
        self.base = base
        self.usesCompute = usesCompute
    }
    func acquireFrame() { base.acquireFrame() }
    func releaseFrame() { base.releaseFrame() }
    func submit(_ commandBuffer: any CommandBuffer) {
        base.submit((commandBuffer as! BenchmarkCommandBuffer).base)
    }
    func makeBuffer(length: Int, memory: BufferMemory) -> (any Buffer)? {
        base.makeBuffer(length: length, memory: memory)
    }
    func makeBuffer(sharing storage: HostBuffer) -> (any Buffer)? { base.makeBuffer(sharing: storage) }
    func makeComputePipeline(function: String) -> (any ComputePipeline)? { base.makeComputePipeline(function: function) }
    func makeRenderPipeline(_ descriptor: RenderPipelineDescriptor) -> (any RenderPipeline)? { base.makeRenderPipeline(descriptor) }
    func makeDepthState(compare: CompareFunction, isWriteEnabled: Bool) -> (any DepthState)? {
        base.makeDepthState(compare: compare, isWriteEnabled: isWriteEnabled)
    }
    func makeCommandBuffer() -> (any CommandBuffer)? { base.makeCommandBuffer().map(BenchmarkCommandBuffer.init) }
    func currentRenderTarget() -> (any RenderTarget)? { base.currentRenderTarget() }
}

private final class BenchmarkCommandBuffer: CommandBuffer {
    let base: any CommandBuffer
    init(_ base: any CommandBuffer) { self.base = base }
    var label: String? { get { base.label } set { base.label = newValue } }
    func makeComputeEncoder() -> (any ComputeEncoder)? { base.makeComputeEncoder() }
    func makeComputeEncoder(timing: GPUComputePhase) -> (any ComputeEncoder)? { base.makeComputeEncoder(timing: timing) }
    func makeRenderEncoder(target: any RenderTarget) -> (any RenderEncoder)? { base.makeRenderEncoder(target: target) }
    func addTimingsHandler(_ handler: @escaping @Sendable (GPUFrameTimings) -> Void) { base.addTimingsHandler(handler) }
    func addCompletedHandler(_ handler: @escaping @Sendable (Double?) -> Void) { base.addCompletedHandler(handler) }
    func present(_ target: any RenderTarget) {}
}

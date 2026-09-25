import Swift

public protocol CommandBuffer: AnyObject {
    var label: String? { get set }
    func makeComputeEncoder(timing: GPUComputePhase) -> (any ComputeEncoder)?
    func makeComputeEncoder() -> (any ComputeEncoder)?
    func makeRenderEncoder(
        target: any RenderTarget
    ) -> (any RenderEncoder)?
    /// Register before encoding to enable optional GPU stage counters.
    func addTimingsHandler(_ handler: @escaping @Sendable (GPUFrameTimings) -> Void)
    func addTraceHandler(frameID: UInt64, captureID: UInt64,
                         _ handler: @escaping @Sendable (GPUTraceInterval) -> Void)
    func present(_ target: any RenderTarget)
    func addCompletedHandler(
        _ handler: @escaping @Sendable (_ gpuDuration: Double?) -> Void
    )
}

public extension CommandBuffer {
    /// Unsupported adapters expose no invented timing intervals.
    func addTraceHandler(frameID: UInt64, captureID: UInt64,
                         _ handler: @escaping @Sendable (GPUTraceInterval) -> Void) {}

    func makeComputeEncoder(timing: GPUComputePhase) -> (any ComputeEncoder)? {
        makeComputeEncoder()
    }

    func addTimingsHandler(_ handler: @escaping @Sendable (GPUFrameTimings) -> Void) {
        addCompletedHandler { handler(.init(total: $0)) }
    }
}

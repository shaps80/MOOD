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
    func present(_ target: any RenderTarget)
    func addCompletedHandler(
        _ handler: @escaping @Sendable (_ gpuDuration: Double?) -> Void
    )
}

public extension CommandBuffer {
    func makeComputeEncoder(timing: GPUComputePhase) -> (any ComputeEncoder)? {
        makeComputeEncoder()
    }

    func addTimingsHandler(_ handler: @escaping @Sendable (GPUFrameTimings) -> Void) {
        addCompletedHandler { handler(.init(total: $0)) }
    }
}

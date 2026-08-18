import Swift

public protocol CommandBuffer: AnyObject {
    var label: String? { get set }
    func makeComputeEncoder() -> (any ComputeEncoder)?
    func makeRenderEncoder(
        target: any RenderTarget
    ) -> (any RenderEncoder)?
    func present(_ target: any RenderTarget)
    func addCompletedHandler(
        _ handler: @escaping @Sendable (_ gpuDuration: Double?) -> Void
    )
}

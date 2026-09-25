import Metal
import PixlRenderer

final class MetalCommandBuffer: PixlRenderer.CommandBuffer {
    private let timingPool: GPUTimingPool
    private var timingSample: GPUTimingSample?
    private var timingHandler: (@Sendable (GPUFrameTimings) -> Void)?
    private var traceHandler: (@Sendable (GPUTraceInterval) -> Void)?
    private var traceFrameID: UInt64 = 0
    private var traceCaptureID: UInt64 = 0
    private let reusableDraw: ReusableDraw
    let value: any MTLCommandBuffer

    var label: String? {
        get { value.label }
        set { value.label = newValue }
    }

    init(_ value: any MTLCommandBuffer, reusableDraw: ReusableDraw, timingPool: GPUTimingPool) {
        self.timingPool = timingPool
        self.value = value
        self.reusableDraw = reusableDraw
    }

    func makeComputeEncoder() -> (any PixlRenderer.ComputeEncoder)? {
        makeComputeEncoder(timing: .preparation)
    }

    func makeComputeEncoder(timing: GPUComputePhase) -> (any PixlRenderer.ComputeEncoder)? {
        guard let timingSample else {
            return value.makeComputeCommandEncoder().map(MetalComputeEncoder.init)
        }
        let descriptor = MTLComputePassDescriptor()
        timingSample.attach(to: descriptor, phase: timing)
        return value.makeComputeCommandEncoder(descriptor: descriptor).map(MetalComputeEncoder.init)
    }

    func makeRenderEncoder(
        target: any PixlRenderer.RenderTarget
    ) -> (any PixlRenderer.RenderEncoder)? {
        guard let target = target as? MetalRenderTarget else {
            preconditionFailure("Render target belongs to another platform")
        }
        timingSample?.attach(to: target.descriptor)
        return value.makeRenderCommandEncoder(descriptor: target.descriptor)
            .map { MetalRenderEncoder($0, reusableDraw: reusableDraw) }
    }

    func addTimingsHandler(_ handler: @escaping @Sendable (GPUFrameTimings) -> Void) {
        precondition(timingHandler == nil)
        timingHandler = handler
        if timingSample == nil { timingSample = timingPool.acquire() }
    }

    func addTraceHandler(frameID: UInt64, captureID: UInt64,
                         _ handler: @escaping @Sendable (GPUTraceInterval) -> Void) {
        traceHandler = handler; traceFrameID = frameID; traceCaptureID = captureID
        if timingSample == nil { timingSample = timingPool.acquire() }
    }

    func prepareForSubmission() {
        let handler = timingHandler
        let trace = traceHandler
        let frameID = traceFrameID, captureID = traceCaptureID
        guard handler != nil || trace != nil else { return }
        let sample = timingSample
        timingSample = nil
        value.addCompletedHandler { [timingPool] commandBuffer in
            defer { if let sample { timingPool.release(sample) } }
            guard commandBuffer.status == .completed else { handler?(.init()); return }
            let elapsed = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
            let total = elapsed > 0 ? elapsed : nil
            if total != nil {
                trace?(.init(phase: .frame, start: commandBuffer.gpuStartTime,
                             end: commandBuffer.gpuEndTime, frameID: frameID, captureID: captureID))
            }
            let timings = sample?.resolve(total: total, trace: trace, frameID: frameID, captureID: captureID) ?? .init(total: total)
            handler?(timings)
        }
    }

    deinit {
        if let timingSample { timingPool.release(timingSample) }
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

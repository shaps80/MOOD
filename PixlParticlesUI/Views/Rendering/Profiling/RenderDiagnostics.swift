import PixlRenderer

struct RenderDiagnostics: Sendable {
    let simulatedCount: Int
    let visibleCount: Int?
    let cpuSimulationTime: Double
    let fixedUpdateTime: Double?
    let cpuRenderTime: Double?
    let gpuTimings: GPUFrameTimings
    var gpuTime: Double? { gpuTimings.total }
    let frameBudget: Double
    let presentationFrameCount: Int
    let presentationDuration: Double
}


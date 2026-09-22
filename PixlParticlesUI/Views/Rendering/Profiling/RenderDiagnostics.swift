struct RenderDiagnostics: Sendable {
    let simulatedCount: Int
    let visibleCount: Int?
    let cpuSimulationTime: Double
    let fixedUpdateTime: Double?
    let cpuRenderTime: Double?
    let gpuTime: Double?
    let frameBudget: Double
    let presentationFrameCount: Int
    let presentationDuration: Double
}


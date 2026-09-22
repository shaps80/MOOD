/// Raw values captured by the render worker; diagnostics are assembled later.
nonisolated struct FrameProfile: Sendable {
    let simulatedCount: Int
    let visibleCount: Int?
    let simulationDuration: Duration
    let fixedUpdateTime: Double?
    let cpuRenderTime: Double?
    let frameBudget: Double
}

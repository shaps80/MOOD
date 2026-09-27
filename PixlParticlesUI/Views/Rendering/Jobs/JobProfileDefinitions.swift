import PixlProfiler
import PixlParticles

nonisolated enum JobProfileDefinitions {
    static let dispatch = ProfileScope(4, "Simulation")
    static let spin = ProfileScope(12, "Spin", kind: .wait)
    static let batch = ProfileScope(5, "Simulation Batch", parentScope: 4)
    static let integrationDispatch = ProfileScope(14, "Integration Batch")
    static let spawnDispatch = ProfileScope(15, "Spawn Disaptch", parentScope: 73)
    static let integrationBatch = ProfileScope(16, "Integration Batch", parentScope: 14)
    static let spawnBatch = ProfileScope(17, "Spawn Batch", parentScope: 15)

    static func dispatch(for kind: SimulationJob.Kind) -> ProfileScope {
        switch kind {
        case .integration: integrationDispatch
        case .spawning: spawnDispatch
        case .unspecified: dispatch
        }
    }
    static func batch(for kind: SimulationJob.Kind) -> ProfileScope {
        switch kind {
        case .integration: integrationBatch
        case .spawning: spawnBatch
        case .unspecified: batch
        }
    }
}

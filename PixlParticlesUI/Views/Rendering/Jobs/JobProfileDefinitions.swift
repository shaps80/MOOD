import PixlProfiler
import PixlParticles

nonisolated enum JobProfileDefinitions {
    static let dispatch = ProfileScope(4, "Simulation")
    static let spin = ProfileScope(12, "Spin for jobs", kind: .wait)
    static let batch = ProfileScope(5, "Simulation batch", parentScope: 4)
    static let integrationDispatch = ProfileScope(14, "Integration")
    static let spawnDispatch = ProfileScope(15, "Generate particles + join", parentScope: 73)
    static let integrationBatch = ProfileScope(16, "Integration batch", parentScope: 14)
    static let spawnBatch = ProfileScope(17, "Spawn batch", parentScope: 15)

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

import PixlProfiler

nonisolated enum JobProfileDefinitions {
    static let dispatch = ProfileScope(4, "Simulation")
    static let spin = ProfileScope(12, "Spin for jobs", kind: .wait)
    static let batch = ProfileScope(5, "Simulation batch")
}

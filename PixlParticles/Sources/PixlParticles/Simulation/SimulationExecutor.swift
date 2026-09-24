import Swift

/// Platform-owned scheduling. Calls are serial and must finish every range before returning.
/// Implementations must not retain a job or its borrowed context after execution.
public protocol SimulationExecutor: AnyObject {
    func execute(_ job: SimulationJob)
}

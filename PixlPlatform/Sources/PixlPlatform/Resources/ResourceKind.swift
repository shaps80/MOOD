import Swift

/// A GPU resource category involved in device creation.
public enum ResourceKind: Hashable, Sendable {
    /// GPU buffer allocation.
    case buffer
    /// Immutable render-pipeline state.
    case renderPipeline
    /// Immutable texture-sampling state.
    case sampler
    /// GPU texture allocation.
    case texture
}

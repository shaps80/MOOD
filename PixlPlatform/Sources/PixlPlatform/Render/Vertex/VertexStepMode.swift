import Swift

/// Frequency at which a vertex buffer advances to its next element.
public enum VertexStepMode: Hashable, Sendable {
    /// Advances once for every vertex.
    case perVertex
    /// Advances once for every instance.
    case perInstance
}

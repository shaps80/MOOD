import Swift

/// Capacity growth applied when an automatically growing indexed buffer fills.
public enum GrowthStrategy: Hashable, Sendable {
    /// Doubles retained capacity whenever the current allocation is exhausted.
    case doubling
}

import Swift

/// Maximum number of distinct non-permanent plans active together.
public enum PlanConcurrency: Hashable, Sendable {
    /// At most one plan may be active.
    case single
    /// At most `count` distinct plans may be active together.
    case upTo(Int)

    var maximumCount: Int {
        switch self {
        case .single:
            return 1
        case .upTo(let count):
            precondition(count > 0, "Plan concurrency must be positive")
            return count
        }
    }

    var reportDescription: String {
        switch self {
        case .single:
            "Single plan"
        case .upTo(let count):
            "Up to \(count) plans"
        }
    }

    var fixDescription: String {
        switch self {
        case .single:
            ".upTo(2)"
        case .upTo(let count):
            ".upTo(\(count + 1))"
        }
    }
}

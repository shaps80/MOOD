import Swift

/// Numeric values shared by the shape SDF shaders.
extension LineCap {
    var renderValue: Double {
        switch self {
        case .butt:
            return 0
        case .square:
            return 1
        case .round:
            return 2
        }
    }
}

/// Numeric values shared by the shape SDF shaders.
extension RoundedCornerStyle {
    var renderValue: Double {
        switch self {
        case .circular:
            return 0
        case .continuous:
            return 1
        }
    }
}

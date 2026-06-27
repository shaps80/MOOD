import Swift

/// The sampling mode a renderer should use when scaling pixel content.
///
/// ```swift
/// let crispPixels = InterpolationMode.nearest
/// let smoothTexture = InterpolationMode.linear
/// ```
public enum InterpolationMode: Equatable, Sendable {
    /// Smoothly blends between source samples.
    ///
    /// ```swift
    /// let mode = InterpolationMode.linear
    /// ```
    case linear

    /// Chooses the nearest source sample, preserving hard pixel edges.
    ///
    /// ```swift
    /// let mode = InterpolationMode.nearest
    /// ```
    case nearest
}

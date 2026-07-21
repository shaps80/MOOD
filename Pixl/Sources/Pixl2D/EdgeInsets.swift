import Swift

/// Insets from each edge of a rectangle.
///
/// Use `EdgeInsets` for camera margins, layout-safe regions, and other
/// platform-neutral spacing values.
///
/// ```swift
/// let margins = EdgeInsets(horizontal: 16, vertical: 12)
/// let totalX = margins.horizontal
/// ```
public struct EdgeInsets: Equatable, Sendable {
    /// The top inset.
    ///
    /// ```swift
    /// let insets = EdgeInsets(all: 8)
    /// let top = insets.top
    /// ```
    public var top: Float

    /// The left inset.
    ///
    /// ```swift
    /// let insets = EdgeInsets(all: 8)
    /// let left = insets.left
    /// ```
    public var left: Float

    /// The bottom inset.
    ///
    /// ```swift
    /// let insets = EdgeInsets(all: 8)
    /// let bottom = insets.bottom
    /// ```
    public var bottom: Float

    /// The right inset.
    ///
    /// ```swift
    /// let insets = EdgeInsets(all: 8)
    /// let right = insets.right
    /// ```
    public var right: Float

    /// Creates insets with explicit edge values.
    ///
    /// ```swift
    /// let insets = EdgeInsets(top: 4, left: 8, bottom: 12, right: 16)
    /// ```
    /// - Parameters:
    ///   - top: Top-edge inset.
    ///   - left: Left-edge inset.
    ///   - bottom: Bottom-edge inset.
    ///   - right: Right-edge inset.
    public init(top: Float, left: Float, bottom: Float, right: Float) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    /// Creates symmetric horizontal and vertical insets.
    ///
    /// ```swift
    /// let insets = EdgeInsets(horizontal: 16, vertical: 8)
    /// ```
    /// - Parameters:
    ///   - horizontal: Value assigned to left and right edges.
    ///   - vertical: Value assigned to top and bottom edges.
    public init(horizontal: Float, vertical: Float) {
        self.init(
            top: vertical,
            left: horizontal,
            bottom: vertical,
            right: horizontal
        )
    }

    /// Creates equal insets on every edge.
    ///
    /// ```swift
    /// let insets = EdgeInsets(all: 10)
    /// ```
    /// - Parameter amount: Value assigned to every edge.
    public init(all amount: Float) {
        self.init(
            top: amount,
            left: amount,
            bottom: amount,
            right: amount
        )
    }

    /// Insets with every edge set to zero.
    ///
    /// ```swift
    /// let insets = EdgeInsets.zero
    /// ```
    public static let zero = EdgeInsets(all: 0)

    /// The combined left and right inset.
    ///
    /// ```swift
    /// let insets = EdgeInsets(horizontal: 16, vertical: 8)
    /// let widthReduction = insets.horizontal
    /// ```
    public var horizontal: Float {
        left + right
    }

    /// The combined top and bottom inset.
    ///
    /// ```swift
    /// let insets = EdgeInsets(horizontal: 16, vertical: 8)
    /// let heightReduction = insets.vertical
    /// ```
    public var vertical: Float {
        top + bottom
    }
}

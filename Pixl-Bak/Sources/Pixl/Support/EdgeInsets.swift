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
    public var top: Double

    /// The left inset.
    ///
    /// ```swift
    /// let insets = EdgeInsets(all: 8)
    /// let left = insets.left
    /// ```
    public var left: Double

    /// The bottom inset.
    ///
    /// ```swift
    /// let insets = EdgeInsets(all: 8)
    /// let bottom = insets.bottom
    /// ```
    public var bottom: Double

    /// The right inset.
    ///
    /// ```swift
    /// let insets = EdgeInsets(all: 8)
    /// let right = insets.right
    /// ```
    public var right: Double

    /// Creates insets with explicit edge values.
    ///
    /// ```swift
    /// let insets = EdgeInsets(top: 4, left: 8, bottom: 12, right: 16)
    /// ```
    public init(top: Double, left: Double, bottom: Double, right: Double) {
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
    public init(horizontal: Double, vertical: Double) {
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
    public init(all amount: Double) {
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
    public var horizontal: Double {
        left + right
    }

    /// The combined top and bottom inset.
    ///
    /// ```swift
    /// let insets = EdgeInsets(horizontal: 16, vertical: 8)
    /// let heightReduction = insets.vertical
    /// ```
    public var vertical: Double {
        top + bottom
    }
}

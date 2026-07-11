import Swift

/// A single edge of a rectangle.
///
/// Use `Edge` for APIs that need one side, and `Edge.Set` for APIs that can
/// operate on multiple sides.
///
/// ```swift
/// let edge = Edge.left
/// let edges: Edge.Set = [.left, .right]
/// ```
public enum Edge: Sendable {
    /// The minimum x edge.
    ///
    /// ```swift
    /// let edge = Edge.left
    /// ```
    case left

    /// The maximum x edge.
    ///
    /// ```swift
    /// let edge = Edge.right
    /// ```
    case right

    /// The minimum y edge.
    ///
    /// ```swift
    /// let edge = Edge.top
    /// ```
    case top

    /// The maximum y edge.
    ///
    /// ```swift
    /// let edge = Edge.bottom
    /// ```
    case bottom

    /// A set of rectangle edges.
    ///
    /// ```swift
    /// let horizontalEdges: Edge.Set = [.left, .right]
    /// let allEdges = Edge.Set.all
    /// ```
    public struct Set: OptionSet, Sendable {
        /// The raw bitmask backing the edge set.
        ///
        /// ```swift
        /// let edges = Edge.Set(rawValue: 0b0011)
        /// let bits = edges.rawValue
        /// ```
        public let rawValue: UInt8

        /// Creates an edge set from a raw bitmask.
        ///
        /// ```swift
        /// let edges = Edge.Set(rawValue: 1 << 0)
        /// ```
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        /// The left edge.
        ///
        /// ```swift
        /// let edges: Edge.Set = [.left]
        /// ```
        public static let left = Set(rawValue: 1 << 0)

        /// The right edge.
        ///
        /// ```swift
        /// let edges: Edge.Set = [.right]
        /// ```
        public static let right = Set(rawValue: 1 << 1)

        /// The top edge.
        ///
        /// ```swift
        /// let edges: Edge.Set = [.top]
        /// ```
        public static let top = Set(rawValue: 1 << 2)

        /// The bottom edge.
        ///
        /// ```swift
        /// let edges: Edge.Set = [.bottom]
        /// ```
        public static let bottom = Set(rawValue: 1 << 3)

        /// Both horizontal edges: left and right.
        ///
        /// ```swift
        /// let edges = Edge.Set.horizontal
        /// ```
        public static let horizontal: Set = [.left, .right]

        /// Both vertical edges: top and bottom.
        ///
        /// ```swift
        /// let edges = Edge.Set.vertical
        /// ```
        public static let vertical: Set = [.top, .bottom]

        /// All rectangle edges.
        ///
        /// ```swift
        /// let edges = Edge.Set.all
        /// ```
        public static let all: Set = [.horizontal, .vertical]
    }
}

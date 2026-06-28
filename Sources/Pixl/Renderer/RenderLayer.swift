import Swift

/// A sortable drawing layer.
///
/// Lower layers draw first. Commands on the same layer keep insertion order.
///
/// ```swift
/// enum Layers {
///     static let background: RenderLayer = 0
///     static let player: RenderLayer = 100
///     static let debug = player + 100
/// }
/// ```
public struct RenderLayer: RawRepresentable, ExpressibleByIntegerLiteral, Comparable, Hashable, Sendable {
    /// The integer layer value.
    public var rawValue: Int

    /// Creates a layer from an integer value.
    public init(_ rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Creates a layer from its raw value.
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Creates a layer from an integer literal.
    public init(integerLiteral value: Int) {
        self.rawValue = value
    }

    /// Sorts lower layer values before higher layer values.
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public extension RenderLayer {
    /// Returns a layer offset above this layer.
    static func + (lhs: Self, rhs: Int) -> Self {
        .init(lhs.rawValue + rhs)
    }

    /// Returns a layer offset below this layer.
    static func - (lhs: Self, rhs: Int) -> Self {
        .init(lhs.rawValue - rhs)
    }
}

import Swift

/// The inset distances for the sides of a rectangle.
@frozen public struct EdgeInsets: Equatable, Sendable {
    public var top: Double = 0
    public var leading: Double = 0
    public var bottom: Double = 0
    public var trailing: Double = 0

    @inlinable public init(top: Double, leading: Double, bottom: Double, trailing: Double) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    @inlinable public init() { }
}

import Swift

/// The inset distances for the sides of a rectangle.
@frozen public struct EdgeInsets: Equatable, Sendable {
    public var top: Float = 0
    public var leading: Float = 0
    public var bottom: Float = 0
    public var trailing: Float = 0

    @inlinable public init(top: Float, leading: Float, bottom: Float, trailing: Float) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    @inlinable public init() { }
}

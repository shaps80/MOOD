import Swift

@frozen public struct BackgroundStyle: ShapeStyle, _FixedColorShapeStyle {
    public typealias Resolved = Never
    @inlinable public init() { }
    @usableFromInline static var color: Color { .background }
}

extension ShapeStyle where Self == BackgroundStyle {
    public static var background: Self { .init() }
}

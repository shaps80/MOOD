import Swift

@frozen public struct PlaceholderTextShapeStyle: ShapeStyle, _FixedColorShapeStyle {
    public typealias Resolved = Never
    @inlinable public init() { }
    @usableFromInline static var color: Color { .placeholder }
}

extension ShapeStyle where Self == PlaceholderTextShapeStyle {
    public static var placeholder: Self { .init() }
}

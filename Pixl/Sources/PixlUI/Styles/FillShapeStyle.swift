import Swift

@frozen public struct FillShapeStyle: ShapeStyle, _FixedColorShapeStyle {
    public typealias Resolved = Never
    @inlinable public init() { }
    @usableFromInline static var color: Color { .fill }
}

extension ShapeStyle where Self == FillShapeStyle {
    public static var fill: Self { .init() }
}

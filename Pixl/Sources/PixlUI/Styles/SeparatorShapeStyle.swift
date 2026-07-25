import Swift

public struct SeparatorShapeStyle: ShapeStyle, _FixedColorShapeStyle {
    public typealias Resolved = Never
    @inlinable public init() { }
    @usableFromInline static var color: Color { .separator }
}

extension ShapeStyle where Self == SeparatorShapeStyle {
    public static var separator: Self { .init() }
}

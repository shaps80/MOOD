import Swift

@frozen public struct TintShapeStyle: ShapeStyle, _TerminalShapeStyle {
    public typealias Resolved = Never

    @inlinable public init() { }

    @usableFromInline func resolveStyle(
        in graph: _Graph,
        environment: EnvironmentValues
    ) -> ViewGraph.StyleID {
        environment.tint
    }
}

extension ShapeStyle where Self == TintShapeStyle {
    public static var tint: Self { .init() }
}

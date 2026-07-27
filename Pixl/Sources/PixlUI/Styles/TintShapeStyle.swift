import Swift

@frozen public struct TintShapeStyle: ShapeStyle, _TerminalShapeStyle {
    public typealias Resolved = Never

    @inlinable public init() { }

    func resolveStyle(
        in graph: _Graph,
        environment: EnvironmentValues
    ) -> ViewGraph.StyleID {
        environment.tint.resolveStyle(
            in: graph,
            environment: environment
        )
    }
}

extension ShapeStyle where Self == TintShapeStyle {
    public static var tint: Self { .init() }
}

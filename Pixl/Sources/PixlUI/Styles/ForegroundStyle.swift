import Swift

@frozen public struct ForegroundStyle: ShapeStyle, _TerminalShapeStyle {
    public typealias Resolved = Never
    @inlinable public init() { }

    func resolveStyle(
        in graph: _Graph,
        environment: EnvironmentValues
    ) -> ViewGraph.StyleID {
        environment.foregroundStyle.resolveStyle(
            in: graph,
            environment: environment
        )
    }
}

extension ShapeStyle where Self == ForegroundStyle {
    public static var foreground: Self { .init() }
}

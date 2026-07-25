import Swift

@frozen public struct ForegroundStyle: ShapeStyle, _TerminalShapeStyle {
    public typealias Resolved = Never
    @inlinable public init() { }

    @usableFromInline func resolveStyle(
        in graph: _Graph,
        environment: _ViewEnvironment
    ) -> ViewGraph.StyleID {
        environment.foregroundStyle
    }
}

extension ShapeStyle where Self == ForegroundStyle {
    public static var foreground: Self { .init() }
}

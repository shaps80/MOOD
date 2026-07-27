import Swift

@frozen public struct OpacityShapeStyleModifier<Base: ShapeStyle>: ShapeStyle, _TerminalShapeStyle {
    public typealias Resolved = Never

    var base: Base
    var opacity: Float

    init(base: Base, opacity: Float) {
        self.base = base
        self.opacity = opacity
    }

    func resolveStyle(
        in graph: _Graph,
        environment: EnvironmentValues
    ) -> ViewGraph.StyleID {
        let baseID = _resolveShapeStyle(base, in: graph, environment: environment)
        let style = graph.styles[Int(baseID.rawValue)].applyingOpacity(opacity)
        return graph.internStyle(style)
    }
}

extension ShapeStyle {
    public func opacity(_ opacity: Float) -> OpacityShapeStyleModifier<Self> {
        OpacityShapeStyleModifier(base: self, opacity: opacity)
    }
}

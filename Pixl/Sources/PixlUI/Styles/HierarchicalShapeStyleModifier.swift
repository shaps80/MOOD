import Swift

@frozen public struct HierarchicalShapeStyleModifier<Base: ShapeStyle>: ShapeStyle, _TerminalShapeStyle {
    public typealias Resolved = Never

    var base: Base
    var level: UInt8

    init(base: Base, level: UInt8) {
        self.base = base
        self.level = level
    }

    func resolveStyle(
        in graph: _Graph,
        environment: EnvironmentValues
    ) -> ViewGraph.StyleID {
        let baseID = _resolveShapeStyle(base, in: graph, environment: environment)
        guard case .color(var color) = graph.styles[Int(baseID.rawValue)] else {
            return baseID
        }
        let opacity: Float
        switch level {
        case 1: opacity = 0.6
        case 2: opacity = 0.3
        case 3: opacity = 0.16
        default: opacity = 0.08
        }
        color.opacity *= opacity
        return graph.internStyle(.color(color))
    }
}

extension ShapeStyle {
    public var secondary: some ShapeStyle {
        HierarchicalShapeStyleModifier(base: self, level: 1)
    }

    public var tertiary: some ShapeStyle {
        HierarchicalShapeStyleModifier(base: self, level: 2)
    }

    public var quaternary: some ShapeStyle {
        HierarchicalShapeStyleModifier(base: self, level: 3)
    }

    public var quinary: some ShapeStyle {
        HierarchicalShapeStyleModifier(base: self, level: 4)
    }
}

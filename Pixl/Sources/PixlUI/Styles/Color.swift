@_exported import PixlGraphics
import Swift

extension Color: ShapeStyle, _TerminalShapeStyle {
    func resolveStyle(
        in graph: _Graph,
        environment: EnvironmentValues
    ) -> ViewGraph.StyleID {
        graph.internStyle(.color(self))
    }
}

extension Color: View {
    public var body: Never { fatalError() }

    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let style = view.value.resolveStyle(
            in: inputs.graph,
            environment: inputs.environment
        )
        let payload = Int32(inputs.graph.primitives.count)
        inputs.graph.primitives.append(.fill(style))
        return .init(node: inputs.graph.appendNode(kind: .primitive, payload: payload, parent: inputs.parent))
    }
}

extension ShapeStyle where Self == Color {
    public static var white: Self { .white }
    public static var black: Self { .black }
    public static var clear: Self { .clear }

    public static var red: Self { .red }
    public static var orange: Self { .orange }
    public static var yellow: Self { .yellow }
    public static var green: Self { .green }
    public static var mint: Self { .mint }
    public static var teal: Self { .teal }
    public static var cyan: Self { .cyan }
    public static var blue: Self { .blue }
    public static var indigo: Self { .indigo }
    public static var purple: Self { .purple }
    public static var pink: Self { .pink }
    public static var brown: Self { .brown }
}

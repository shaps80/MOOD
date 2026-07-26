import Swift

public struct _ForegroundStyleModifier<Style: ShapeStyle>: ViewModifier {
    public typealias Body = Never
    public var style: Style

    @inlinable public init(style: Style) { self.style = style }

    public static func _makeView(
        modifier: _GraphValue<Self>,
        inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs
    ) -> _ViewOutputs {
        var inputs = inputs
        let style = _resolveShapeStyle(
            modifier.value.style,
            in: inputs.graph,
            environment: inputs.environment
        )
        inputs.environment.foregroundStyle = style
        let outputs = body(inputs.graph, inputs)
        let node = inputs.graph.nodes[Int(outputs.node.rawValue)]
        if node.kind == .shape {
            inputs.graph.shapes[Int(node.payload)].fill = style
        }
        return outputs
    }

    public static func _makeViewList(
        modifier: _GraphValue<Self>,
        inputs: _ViewListInputs,
        body: @escaping (_Graph, _ViewListInputs) -> _ViewListOutputs
    ) -> _ViewListOutputs {
        var inputs = inputs
        inputs.environment.foregroundStyle = _resolveShapeStyle(
            modifier.value.style,
            in: inputs.graph,
            environment: inputs.environment
        )
        return body(inputs.graph, inputs)
    }
}

extension View {
    @inlinable public func foregroundStyle<S: ShapeStyle>(_ style: S) -> some View {
        modifier(_ForegroundStyleModifier(style: style))
    }
}

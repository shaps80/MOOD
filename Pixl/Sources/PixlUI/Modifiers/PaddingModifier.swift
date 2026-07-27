import Swift

public struct _PaddingModifier: ViewModifier {
    public typealias Body = Never
    public var insets: EdgeInsets

    public static func _makeView(
        modifier: _GraphValue<Self>,
        inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs
    ) -> _ViewOutputs {
        let payload = Int32(inputs.graph.layouts.count)
        inputs.graph.layouts.append(.init(box: _LayoutBox(_PaddingLayout(insets: modifier.value.insets))))
        let node = inputs.graph.appendNode(kind: .layout, payload: payload, parent: inputs.parent)
        _ = body(inputs.graph, .init(
            graph: inputs.graph,
            parent: node,
            environment: inputs.environment,
            identity: inputs.identity
        ))
        return .init(node: node)
    }

}

extension View {
    @ContentBuilder
    public func padding(_ insets: EdgeInsets) -> some View {
        modifier(_PaddingModifier(insets: insets))
    }

    @ContentBuilder
    public func padding(_ length: Float) -> some View {
        padding(.all, length)
    }

    @ContentBuilder
    public func padding(_ edges: Edge.Set = .all, _ length: Float? = nil) -> some View {
        let length = length ?? 10
        padding(.init(
            top: edges.contains(.top) ? length : 0,
            leading: edges.contains(.leading) ? length : 0,
            bottom: edges.contains(.bottom) ? length : 0,
            trailing: edges.contains(.trailing) ? length : 0
        ))
    }
}

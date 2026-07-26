import Swift

@frozen public struct _LayoutView<L: Layout, Content: View>: View {
    public let layout: L
    public let content: Content
    @inlinable public init(layout: L, content: Content) { self.layout = layout; self.content = content }
    public var body: Never { fatalError() }

    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let payload = Int32(inputs.graph.layouts.count)
        inputs.graph.layouts.append(.init(box: _LayoutBox(view.value.layout)))
        let node = inputs.graph.appendNode(kind: .layout, payload: payload, parent: inputs.parent)
        _ = Content._makeViewList(
            view: .init(view.value.content, graph: view.graph),
            inputs: .init(
                graph: inputs.graph,
                parent: node,
                environment: inputs.environment,
                identity: inputs.identity
            )
        )
        return .init(node: node)
    }
}

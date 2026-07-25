import Swift

@frozen public struct ZStack<Content: View>: View {
    public let alignment: Alignment
    public let content: Content

    @inlinable public init(
        alignment: Alignment = .center,
        @ContentBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.content = content()
    }

    public var body: Never { fatalError() }

    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let payload = Int32(inputs.graph.stacks.count)
        inputs.graph.stacks.append(
            .init(
                axis: .depth,
                spacing: nil,
                horizontalAlignment: nil,
                verticalAlignment: nil,
                alignment: view.value.alignment
            )
        )
        let node = inputs.graph.appendNode(
            kind: .depthStack,
            payload: payload,
            parent: inputs.parent
        )
        _ = Content._makeViewList(
            view: .init(view.value.content, graph: view.graph),
            inputs: .init(
                graph: inputs.graph,
                parent: node,
                modifierBody: inputs.modifierBodyList,
                modifierBodyView: inputs.modifierBody
            )
        )
        return .init(node: node)
    }
}

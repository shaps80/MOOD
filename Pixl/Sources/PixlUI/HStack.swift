import Swift

@frozen public struct HStack<Content: View>: View {
    public let alignment: VerticalAlignment
    public let spacing: Double?
    public let content: Content

    @inlinable public init(
        alignment: VerticalAlignment = .center,
        spacing: Double? = nil,
        @ContentBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public var body: Never { fatalError() }

    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let payload = Int32(inputs.graph.stacks.count)
        inputs.graph.stacks.append(
            .init(
                axis: .horizontal,
                spacing: view.value.spacing,
                horizontalAlignment: nil,
                verticalAlignment: view.value.alignment,
                alignment: nil
            )
        )
        let node = inputs.graph.appendNode(
            kind: .horizontalStack,
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

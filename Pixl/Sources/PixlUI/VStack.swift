import Swift

@frozen public struct VStack<Content: View>: View {
    public let alignment: HorizontalAlignment
    public let spacing: Double?
    public let content: Content

    @inlinable public init(
        alignment: HorizontalAlignment = .center,
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
                axis: .vertical,
                spacing: view.value.spacing,
                horizontalAlignment: view.value.alignment,
                verticalAlignment: nil,
                alignment: nil
            )
        )
        let node = inputs.graph.appendNode(
            kind: .verticalStack,
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

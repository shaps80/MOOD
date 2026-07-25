import Swift

@frozen public struct _BackgroundModifier<Background: View>: ViewModifier {
    public typealias Body = Never

    public var background: Background
    public var alignment: Alignment

    @inlinable public init(
        background: Background,
        alignment: Alignment = .center
    ) {
        self.background = background
        self.alignment = alignment
    }

    public static func _makeView(
        modifier: _GraphValue<Self>,
        inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs
    ) -> _ViewOutputs {
        let payload = Int32(inputs.graph.layers.count)
        inputs.graph.layers.append(.init(alignment: modifier.value.alignment))
        let node = inputs.graph.appendNode(
            kind: .background,
            payload: payload,
            parent: inputs.parent
        )
        _ = Background._makeView(
            view: .init(modifier.value.background, graph: modifier.graph),
            inputs: .init(
                graph: inputs.graph,
                parent: node,
                modifierBody: inputs.modifierBody,
                modifierBodyList: inputs.modifierBodyList
            )
        )
        _ = body(
            inputs.graph,
            .init(
                graph: inputs.graph,
                parent: node,
                modifierBody: inputs.modifierBody,
                modifierBodyList: inputs.modifierBodyList
            )
        )
        return .init(node: node)
    }

    public static func _makeViewList(
        modifier: _GraphValue<Self>,
        inputs: _ViewListInputs,
        body: @escaping (_Graph, _ViewListInputs) -> _ViewListOutputs
    ) -> _ViewListOutputs {
        let payload = Int32(inputs.graph.layers.count)
        inputs.graph.layers.append(.init(alignment: modifier.value.alignment))
        let node = inputs.graph.appendNode(
            kind: .background,
            payload: payload,
            parent: inputs.parent
        )
        _ = Background._makeView(
            view: .init(modifier.value.background, graph: modifier.graph),
            inputs: .init(
                graph: inputs.graph,
                parent: node,
                modifierBody: inputs.modifierBodyView,
                modifierBodyList: inputs.modifierBody
            )
        )
        _ = body(
            inputs.graph,
            .init(
                graph: inputs.graph,
                parent: node,
                modifierBody: inputs.modifierBody,
                modifierBodyView: inputs.modifierBodyView
            )
        )
        return .init(first: node, last: node, count: 1)
    }
}

extension View {
    @inlinable public func background<Background: View>(
        alignment: Alignment = .center,
        @ContentBuilder content: () -> Background
    ) -> some View {
        modifier(
            _BackgroundModifier(
                background: content(),
                alignment: alignment
            )
        )
    }
}

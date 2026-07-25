import Swift

@frozen public struct _OverlayModifier<Overlay: View>: ViewModifier {
    public typealias Body = Never

    public var overlay: Overlay
    public var alignment: Alignment

    @inlinable public init(
        overlay: Overlay,
        alignment: Alignment = .center
    ) {
        self.overlay = overlay
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
            kind: .overlay,
            payload: payload,
            parent: inputs.parent
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
        _ = Overlay._makeView(
            view: .init(modifier.value.overlay, graph: modifier.graph),
            inputs: .init(
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
            kind: .overlay,
            payload: payload,
            parent: inputs.parent
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
        _ = Overlay._makeView(
            view: .init(modifier.value.overlay, graph: modifier.graph),
            inputs: .init(
                graph: inputs.graph,
                parent: node,
                modifierBody: inputs.modifierBodyView,
                modifierBodyList: inputs.modifierBody
            )
        )
        return .init(first: node, last: node, count: 1)
    }
}

extension View {
    @inlinable public func overlay<Overlay: View>(
        alignment: Alignment = .center,
        @ContentBuilder content: () -> Overlay
    ) -> some View {
        modifier(
            _OverlayModifier(
                overlay: content(),
                alignment: alignment
            )
        )
    }
}

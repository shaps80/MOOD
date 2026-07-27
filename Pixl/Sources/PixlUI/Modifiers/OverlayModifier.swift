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
        let payload = Int32(inputs.graph.compositions.count)
        inputs.graph.compositions.append(.init(order: .overlay, alignment: modifier.value.alignment))
        let node = inputs.graph.appendNode(
            kind: .composition,
            payload: payload,
            parent: inputs.parent
        )
        _ = body(
            inputs.graph,
            .init(
                graph: inputs.graph,
                parent: node,
                environment: inputs.environment,
                identity: inputs.identity.child(0)
            )
        )
        _ = Overlay._makeView(
            view: .init(modifier.value.overlay, graph: modifier.graph),
            inputs: .init(
                graph: inputs.graph,
                parent: node,
                environment: inputs.environment,
                identity: inputs.identity.child(1)
            )
        )
        return .init(node: node)
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

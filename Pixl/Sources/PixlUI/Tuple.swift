import Swift

@frozen public struct TupleContent<each Content> {
    public var body: Never { fatalError() }
    public var content: (repeat each Content)

    @inlinable public init(_ content: repeat each Content) {
        self.content = (repeat each content)
    }
}

extension TupleContent: View where repeat each Content: View {
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let node = inputs.graph.appendNode(kind: .group, parent: inputs.parent)
        _ = _makeViewList(
            view: view,
            inputs: .init(graph: inputs.graph, parent: node)
        )
        return .init(node: node)
    }

    public static func _makeViewList(
        view: _GraphValue<Self>,
        inputs: _ViewListInputs
    ) -> _ViewListOutputs {
        var first = ViewGraph.NodeID.invalid
        var last = ViewGraph.NodeID.invalid
        var count = 0

        for child in repeat each view.value.content {
            let output = type(of: child)._makeViewList(
                view: .init(child, graph: view.graph),
                inputs: inputs
            )
            if !first.isValid { first = output.first }
            if output.last.isValid { last = output.last }
            count += output.count
        }

        return .init(first: first, last: last, count: count)
    }
}

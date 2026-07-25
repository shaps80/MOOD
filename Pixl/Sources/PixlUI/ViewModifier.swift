import Swift

public protocol ViewModifier {
    associatedtype Body: View

    typealias Content = _ViewModifier_Content<Self>

    @ContentBuilder
    func body(content: Content) -> Body

    @_documentation(visibility: internal)
    static func _makeView(
        modifier: _GraphValue<Self>,
        inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs
    ) -> _ViewOutputs

    @_documentation(visibility: internal)
    static func _makeViewList(
        modifier: _GraphValue<Self>,
        inputs: _ViewListInputs,
        body: @escaping (_Graph, _ViewListInputs) -> _ViewListOutputs
    ) -> _ViewListOutputs
}

extension ViewModifier {
    public static func _makeView(
        modifier: _GraphValue<Self>,
        inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs
    ) -> _ViewOutputs {
        let content = modifier.value.body(content: .init())
        let bodyList: (_Graph, _ViewListInputs) -> _ViewListOutputs = { graph, inputs in
            let output = body(
                graph,
                .init(graph: inputs.graph, parent: inputs.parent)
            )
            return .init(first: output.node, last: output.node, count: 1)
        }
        return Body._makeView(
            view: .init(content, graph: modifier.graph),
            inputs: .init(
                graph: inputs.graph,
                parent: inputs.parent,
                modifierBody: body,
                modifierBodyList: bodyList
            )
        )
    }

    public static func _makeViewList(
        modifier: _GraphValue<Self>,
        inputs: _ViewListInputs,
        body: @escaping (_Graph, _ViewListInputs) -> _ViewListOutputs
    ) -> _ViewListOutputs {
        let content = modifier.value.body(content: .init())
        let bodyView: (_Graph, _ViewInputs) -> _ViewOutputs = { graph, inputs in
            let output = body(
                graph,
                .init(graph: inputs.graph, parent: inputs.parent)
            )
            guard output.first.isValid else {
                return .init(
                    node: inputs.graph.appendNode(kind: .empty, parent: inputs.parent)
                )
            }
            return .init(node: output.first)
        }
        return Body._makeViewList(
            view: .init(content, graph: modifier.graph),
            inputs: .init(
                graph: inputs.graph,
                parent: inputs.parent,
                modifierBody: body,
                modifierBodyView: bodyView
            )
        )
    }
}

extension ViewModifier where Body == Never {
    public func body(content: Content) -> Never { fatalError() }
}

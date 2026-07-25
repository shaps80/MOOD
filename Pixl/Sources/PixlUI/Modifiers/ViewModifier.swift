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
                .init(graph: inputs.graph, parent: inputs.parent, environment: inputs.environment)
            )
            return .init(first: output.node, last: output.node, count: 1)
        }
        return Body._makeView(
            view: .init(content, graph: modifier.graph),
            inputs: .init(
                graph: inputs.graph,
                parent: inputs.parent,
                environment: inputs.environment,
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
        let output = _makeView(
            modifier: modifier,
            inputs: .init(
                graph: inputs.graph,
                parent: inputs.parent,
                environment: inputs.environment,
                modifierBody: inputs.modifierBodyView,
                modifierBodyList: inputs.modifierBody
            )
        ) { graph, viewInputs in
            let group = graph.appendNode(kind: .group, parent: viewInputs.parent)
            _ = body(
                graph,
                .init(
                    graph: graph,
                    parent: group,
                    environment: viewInputs.environment,
                    modifierBody: viewInputs.modifierBodyList,
                    modifierBodyView: viewInputs.modifierBody
                )
            )
            return .init(node: group)
        }
        return .init(first: output.node, last: output.node, count: 1)
    }
}

extension ViewModifier where Body == Never {
    public func body(content: Content) -> Never { fatalError() }
}

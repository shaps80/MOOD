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
        let content = _EnvironmentRuntime.$context.withValue(
            .init(values: inputs.environment)
        ) {
            _StateRuntime.$context.withValue(
                .init(
                    store: modifier.graph.stateStore,
                    path: inputs.identity.path,
                    viewType: ObjectIdentifier(Self.self)
                )
            ) {
                modifier.value.body(content: .init())
            }
        }
        let bodyList: (_Graph, _ViewListInputs) -> _ViewListOutputs = { graph, inputs in
            let output = body(
                graph,
                .init(
                    graph: inputs.graph,
                    parent: inputs.parent,
                    environment: inputs.environment,
                    identity: inputs.identity
                )
            )
            return .init(first: output.node, last: output.node, count: 1)
        }
        return _ViewModifierRuntime.$content.withValue(
            .init(makeView: body, makeViewList: bodyList)
        ) {
            Body._makeView(
                view: .init(content, graph: modifier.graph),
                inputs: inputs
            )
        }
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
                identity: inputs.identity
            )
        ) { graph, viewInputs in
            let group = graph.appendNode(kind: .group, parent: viewInputs.parent)
            _ = body(
                graph,
                .init(
                    graph: graph,
                    parent: group,
                    environment: viewInputs.environment,
                    identity: viewInputs.identity
                )
            )
            return .init(node: group)
        }
        return .init(first: output.node, last: output.node, count: 1)
    }
}

extension Never: ViewModifier { }
extension ViewModifier where Body == Never {
    public func body(content: Content) -> Never { fatalError() }
}

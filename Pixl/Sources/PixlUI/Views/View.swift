import Swift

public protocol View {
    associatedtype Body: View
    @ContentBuilder
    var body: Body { get }

    @_documentation(visibility: internal)
    static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs

    @_documentation(visibility: internal)
    static func _makeViewList(view: _GraphValue<Self>, inputs: _ViewListInputs) -> _ViewListOutputs
}

extension View {
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let body = _EnvironmentRuntime.$context.withValue(
            .init(values: inputs.environment)
        ) {
            _StateRuntime.$context.withValue(
                .init(
                    store: view.graph.stateStore,
                    path: inputs.identity.path,
                    viewType: ObjectIdentifier(Self.self)
                )
            ) {
                view.value.body
            }
        }
        return Body._makeView(
            view: .init(body, graph: view.graph),
            inputs: inputs
        )
    }

    public static func _makeViewList(
        view: _GraphValue<Self>,
        inputs: _ViewListInputs
    ) -> _ViewListOutputs {
        let output = _makeView(
            view: view,
            inputs: .init(
                graph: inputs.graph,
                parent: inputs.parent,
                environment: inputs.environment,
                identity: inputs.identity
            )
        )
        return .init(first: output.node, last: output.node, count: 1)
    }
}

extension Never: View {
    public var body: Never { fatalError() }
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        fatalError("Never cannot be built as a view")
    }
}

public struct EmptyView: View {
    @inlinable public init() { }

    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        .init(node: inputs.graph.appendNode(kind: .empty, parent: inputs.parent))
    }

    public static func _makeViewList(
        view: _GraphValue<Self>,
        inputs: _ViewListInputs
    ) -> _ViewListOutputs {
        .init()
    }
}

extension View where Body == Never {
    public var body: Never { fatalError() }
}

public typealias EmptyContent = EmptyView

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
        Body._makeView(
            view: .init(view.value.body, graph: view.graph),
            inputs: inputs
        )
    }

    public static func _makeViewList(
        view: _GraphValue<Self>,
        inputs: _ViewListInputs
    ) -> _ViewListOutputs {
        let output = _makeView(
            view: view,
            inputs: .init(graph: inputs.graph, parent: inputs.parent)
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

    public var body: Never { fatalError() }
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

public typealias EmptyContent = EmptyView

import Swift

@frozen public struct _ConditionalContent<TrueContent, FalseContent> {
    public var body: Never { fatalError() }

    @usableFromInline let storage: Storage
    @usableFromInline init(storage: Storage) {
        self.storage = storage
    }

    @usableFromInline @frozen 
    internal enum Storage {
        case trueContent(TrueContent)
        case falseContent(FalseContent)
    }
}

extension _ConditionalContent: View where TrueContent: View, FalseContent: View {
    public static func _makeView(
        view: _GraphValue<Self>,
        inputs: _ViewInputs
    ) -> _ViewOutputs {
        switch view.value.storage {
        case let .trueContent(content):
            TrueContent._makeView(
                view: .init(content, graph: view.graph),
                inputs: inputs.withIdentity(inputs.identity.child(0))
            )
        case let .falseContent(content):
            FalseContent._makeView(
                view: .init(content, graph: view.graph),
                inputs: inputs.withIdentity(inputs.identity.child(1))
            )
        }
    }

    public static func _makeViewList(
        view: _GraphValue<Self>,
        inputs: _ViewListInputs
    ) -> _ViewListOutputs {
        switch view.value.storage {
        case let .trueContent(content):
            TrueContent._makeViewList(
                view: .init(content, graph: view.graph),
                inputs: inputs.withIdentity(inputs.identity.child(0))
            )
        case let .falseContent(content):
            FalseContent._makeViewList(
                view: .init(content, graph: view.graph),
                inputs: inputs.withIdentity(inputs.identity.child(1))
            )
        }
    }
}

extension Optional: View where Wrapped: View {
    public typealias Body = Never

    public var body: Never { fatalError() }

    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let value = view.value else {
            return .init(node: inputs.graph.appendNode(kind: .empty, parent: inputs.parent))
        }
        return Wrapped._makeView(
            view: .init(value, graph: view.graph),
            inputs: inputs
        )
    }

    public static func _makeViewList(
        view: _GraphValue<Self>,
        inputs: _ViewListInputs
    ) -> _ViewListOutputs {
        guard let value = view.value else { return .init() }
        return Wrapped._makeViewList(
            view: .init(value, graph: view.graph),
            inputs: inputs
        )
    }
}

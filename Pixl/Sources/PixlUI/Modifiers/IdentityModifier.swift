import Swift

@frozen public struct _IdentityView<Content: View, ID: Hashable>: View {
    public let content: Content
    public let id: ID

    @inlinable init(content: Content, id: ID) {
        self.content = content
        self.id = id
    }

    public var body: Never { fatalError() }

    public static func _makeView(
        view: _GraphValue<Self>,
        inputs: _ViewInputs
    ) -> _ViewOutputs {
        Content._makeView(
            view: .init(view.value.content, graph: view.graph),
            inputs: inputs.withIdentity(inputs.identity.explicit(view.value.id))
        )
    }

    public static func _makeViewList(
        view: _GraphValue<Self>,
        inputs: _ViewListInputs
    ) -> _ViewListOutputs {
        Content._makeViewList(
            view: .init(view.value.content, graph: view.graph),
            inputs: inputs.withIdentity(inputs.identity.explicit(view.value.id))
        )
    }
}

extension View {
    @inlinable public func id<ID: Hashable>(_ id: ID) -> _IdentityView<Self, ID> {
        .init(content: self, id: id)
    }
}

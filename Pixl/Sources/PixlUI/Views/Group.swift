import Swift

@frozen public struct Group<Content: View>: View {
    public typealias Body = Never

    public let content: Content

    @inlinable public init(
        @ContentBuilder content: () -> Content
    ) {
        self.content = content()
    }

    public var body: Never { fatalError() }

    public static func _makeView(
        view: _GraphValue<Self>,
        inputs: _ViewInputs
    ) -> _ViewOutputs {
        Content._makeView(
            view: .init(view.value.content, graph: view.graph),
            inputs: inputs.withIdentity(inputs.identity.child(0))
        )
    }

    public static func _makeViewList(
        view: _GraphValue<Self>,
        inputs: _ViewListInputs
    ) -> _ViewListOutputs {
        Content._makeViewList(
            view: .init(view.value.content, graph: view.graph),
            inputs: inputs.withIdentity(inputs.identity.child(0))
        )
    }
}

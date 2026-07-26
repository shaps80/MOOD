import Swift

@frozen public struct ModifiedContent<Content, Modifier> {
    public var content: Content
    public var modifier: Modifier

    @inlinable public init(content: Content, modifier: Modifier) {
        self.content = content
        self.modifier = modifier
    }
}

extension ModifiedContent: View where Content: View, Modifier: ViewModifier {
    public typealias Body = Never

    public var body: Never { fatalError() }

    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        Modifier._makeView(
            modifier: .init(view.value.modifier, graph: view.graph),
            inputs: inputs.withIdentity(inputs.identity.child(0))
        ) { graph, inputs in
            Content._makeView(
                view: .init(view.value.content, graph: graph),
                inputs: inputs.withIdentity(inputs.identity.child(1))
            )
        }
    }

    public static func _makeViewList(
        view: _GraphValue<Self>,
        inputs: _ViewListInputs
    ) -> _ViewListOutputs {
        Modifier._makeViewList(
            modifier: .init(view.value.modifier, graph: view.graph),
            inputs: inputs.withIdentity(inputs.identity.child(0))
        ) { graph, inputs in
            Content._makeViewList(
                view: .init(view.value.content, graph: graph),
                inputs: inputs.withIdentity(inputs.identity.child(1))
            )
        }
    }
}

extension View {
    @inlinable public func modifier<Modifier: ViewModifier>(
        _ modifier: Modifier
    ) -> ModifiedContent<Self, Modifier> {
        .init(content: self, modifier: modifier)
    }
}

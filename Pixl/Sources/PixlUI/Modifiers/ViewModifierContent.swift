import Swift

public struct _ViewModifier_Content<Modifier: ViewModifier>: View {
    public typealias Body = Never

    public var body: Never { fatalError() }

    @usableFromInline init() { }

    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let body = inputs.modifierBody else {
            fatalError("ViewModifier.Content used outside its modifier body")
        }
        return body(inputs.graph, inputs)
    }

    public static func _makeViewList(
        view: _GraphValue<Self>,
        inputs: _ViewListInputs
    ) -> _ViewListOutputs {
        guard let body = inputs.modifierBody else {
            fatalError("ViewModifier.Content used outside its modifier body")
        }
        return body(inputs.graph, inputs)
    }
}

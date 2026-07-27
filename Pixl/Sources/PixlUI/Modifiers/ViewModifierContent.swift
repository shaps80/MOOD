import Swift

struct _ViewModifierContentContext: @unchecked Sendable {
    let makeView: (_Graph, _ViewInputs) -> _ViewOutputs
    let makeViewList: (_Graph, _ViewListInputs) -> _ViewListOutputs
}

enum _ViewModifierRuntime {
    @TaskLocal static var content: _ViewModifierContentContext?
}

public struct _ViewModifier_Content<Modifier: ViewModifier>: View {
    public typealias Body = Never

    public var body: Never { fatalError() }

    @usableFromInline init() { }

    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        guard let content = _ViewModifierRuntime.content else {
            fatalError("ViewModifier.Content used outside its modifier body")
        }
        return content.makeView(inputs.graph, inputs)
    }

    public static func _makeViewList(
        view: _GraphValue<Self>,
        inputs: _ViewListInputs
    ) -> _ViewListOutputs {
        guard let content = _ViewModifierRuntime.content else {
            fatalError("ViewModifier.Content used outside its modifier body")
        }
        return content.makeViewList(inputs.graph, inputs)
    }
}

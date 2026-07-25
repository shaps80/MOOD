import Swift

public struct Text: View {
    internal var content: String

    public static func _makeView(view: _GraphValue<Text>, inputs: _ViewInputs) -> _ViewOutputs {
        let payload = Int32(inputs.graph.texts.count)
        inputs.graph.texts.append(.init(content: view.value.content))
        return .init(
            node: inputs.graph.appendNode(
                kind: .text,
                payload: payload,
                parent: inputs.parent
            )
        )
    }
}

extension Text {
    public init(_ value: String) {
        content = value
    }
}

extension Text {
    public var body: Never { fatalError() }
}

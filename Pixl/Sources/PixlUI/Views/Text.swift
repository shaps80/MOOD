import Swift

public struct Text: View {
    internal var content: String

    public static func _makeView(view: _GraphValue<Text>, inputs: _ViewInputs) -> _ViewOutputs {
        let payload = Int32(inputs.graph.primitives.count)
        inputs.graph.primitives.append(
            .text(.init(
                content: view.value.content,
                foregroundStyle: inputs.environment.foregroundStyle
            ))
        )
        return .init(
            node: inputs.graph.appendNode(
                kind: .primitive,
                payload: payload,
                parent: inputs.parent
            )
        )
    }
}

extension Text {
    public init(_ value: some StringProtocol) {
        content = .init(value)
    }
}

extension Text {
    public var body: Never { fatalError() }
}

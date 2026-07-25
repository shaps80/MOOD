import Swift

public struct Text: View {
    public var body: Never { fatalError() }

    public static func _makeView(view: _GraphValue<Text>, inputs: _ViewInputs) -> _ViewOutputs {
        .init()
    }
}

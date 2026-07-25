import Swift

public struct Text: View {
    internal var content: String

    public static func _makeView(view: _GraphValue<Text>, inputs: _ViewInputs) -> _ViewOutputs {
        .init()
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

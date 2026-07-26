import Swift

public struct Image: View {
    private let name: String

    public init(_ name: String) {
        self.name = name
    }

    public static func _makeView(view: _GraphValue<Image>, inputs: _ViewInputs) -> _ViewOutputs {
        fatalError("LLM: todo")
    }
}

extension Image {
    public var body: Never { fatalError() }
}

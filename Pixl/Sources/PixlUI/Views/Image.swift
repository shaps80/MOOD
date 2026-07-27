import Swift

public struct Image: View {
    private let name: String
    private var mode: RenderingMode = .original

    public enum RenderingMode: Sendable {
        case original
        case template
    }

    public init(_ name: String) {
        self.name = name
    }

    public func renderingMode(_ renderingMode: RenderingMode) -> Image {
        var copy = self
        copy.mode = renderingMode
        return copy
    }

    public static func _makeView(view: _GraphValue<Image>, inputs: _ViewInputs) -> _ViewOutputs {
        let payload = Int32(inputs.graph.primitives.count)
        inputs.graph.primitives.append(
            .image(.init(
                name: view.value.name,
                renderingMode: view.value.mode,
                tint: inputs.environment.tint,
                asset: nil
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

extension Image {
    public var body: Never { fatalError() }
}

import Swift

public struct Image: View {
    private let name: String

    public enum RenderingMode: Sendable {
        case original
        case template
    }

    public init(_ name: String) {
        self.name = name
    }

    public static func _makeView(view: _GraphValue<Image>, inputs: _ViewInputs) -> _ViewOutputs {
        let payload = Int32(inputs.graph.primitives.count)
        inputs.graph.primitives.append(
            .image(.init(
                name: view.value.name,
                renderingMode: inputs.environment.imageRenderingMode,
                tint: inputs.environment.tint.resolveStyle(
                    in: inputs.graph,
                    environment: inputs.environment
                ),
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

extension EnvironmentValues {
    @Entry public var imageRenderingMode: Image.RenderingMode = .original
}

extension View {
    public func renderingMode(
        _ renderingMode: Image.RenderingMode
    ) -> some View {
        environment(\.imageRenderingMode, renderingMode)
    }
}

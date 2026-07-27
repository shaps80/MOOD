import Swift

@frozen public struct Divider: View {
    @usableFromInline var style: AnyShapeStyle

    @inlinable public init() {
        style = AnyShapeStyle(.separator)
    }

    public var body: Never { fatalError() }

    public func foregroundStyle<S: ShapeStyle>(_ style: S) -> Divider {
        var copy = self
        copy.style = AnyShapeStyle(style)
        return copy
    }

    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let style = view.value.style.resolveStyle(
            in: inputs.graph,
            environment: inputs.environment
        )
        let payload = Int32(inputs.graph.primitives.count)
        inputs.graph.primitives.append(.divider(style))
        return .init(node: inputs.graph.appendNode(kind: .primitive, payload: payload, parent: inputs.parent))
    }
}

import Swift

@frozen public struct Spacer: View {
    public var minLength: Float?
    @inlinable public init(minLength: Float? = nil) { self.minLength = minLength }
    public var body: Never { fatalError() }
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let payload = Int32(inputs.graph.primitives.count); inputs.graph.primitives.append(.spacer(minLength: view.value.minLength))
        return .init(node: inputs.graph.appendNode(kind: .primitive, payload: payload, parent: inputs.parent))
    }
}

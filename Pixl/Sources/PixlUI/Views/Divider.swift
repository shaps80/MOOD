import Swift

@frozen public struct Divider: View {
    @inlinable public init() { }
    public var body: Never { fatalError() }
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let payload = Int32(inputs.graph.primitives.count); inputs.graph.primitives.append(.divider)
        return .init(node: inputs.graph.appendNode(kind: .primitive, payload: payload, parent: inputs.parent))
    }
}

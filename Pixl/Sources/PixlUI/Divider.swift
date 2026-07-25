import Swift

@frozen public struct Divider: View {
    @inlinable public init() { }
    public var body: Never { fatalError() }
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        .init(node: inputs.graph.appendNode(kind: .divider, parent: inputs.parent))
    }
}

import Swift

public struct _FrameModifier: ViewModifier {
    public typealias Body = Never
    public var minWidth: Float?; public var idealWidth: Float?; public var maxWidth: Float?
    public var minHeight: Float?; public var idealHeight: Float?; public var maxHeight: Float?
    public var alignment: Alignment
    public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs, body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        let payload = Int32(inputs.graph.layouts.count)
        inputs.graph.layouts.append(.init(box: _LayoutBox(_FrameLayout(modifier.value))))
        let node = inputs.graph.appendNode(kind: .layout, payload: payload, parent: inputs.parent)
        _ = body(inputs.graph, .init(
            graph: inputs.graph,
            parent: node,
            environment: inputs.environment,
            identity: inputs.identity
        ))
        return .init(node: node)
    }

}

extension View {
    public func frame(width: Float? = nil, height: Float? = nil, alignment: Alignment = .center) -> some View {
        modifier(_FrameModifier(minWidth: width, idealWidth: width, maxWidth: width, minHeight: height, idealHeight: height, maxHeight: height, alignment: alignment))
    }
    public func frame(minWidth: Float? = nil, idealWidth: Float? = nil, maxWidth: Float? = nil, minHeight: Float? = nil, idealHeight: Float? = nil, maxHeight: Float? = nil, alignment: Alignment = .center) -> some View {
        modifier(_FrameModifier(minWidth: minWidth, idealWidth: idealWidth, maxWidth: maxWidth, minHeight: minHeight, idealHeight: idealHeight, maxHeight: maxHeight, alignment: alignment))
    }
}

import Swift

struct _HiddenModifier: ViewModifier {
    typealias Body = Never

    init() { }

    static func _makeView(
        modifier: _GraphValue<Self>,
        inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs
    ) -> _ViewOutputs {
        let outputs = body(inputs.graph, inputs)
        inputs.graph.hideSubtree(outputs.node)
        return outputs
    }

    static func _makeViewList(
        modifier: _GraphValue<Self>,
        inputs: _ViewListInputs,
        body: @escaping (_Graph, _ViewListInputs) -> _ViewListOutputs
    ) -> _ViewListOutputs {
        let outputs = body(inputs.graph, inputs)
        var node = outputs.first
        while node.isValid {
            let next = inputs.graph.nodes[Int(node.rawValue)].nextSibling
            inputs.graph.hideSubtree(node)
            if node == outputs.last { break }
            node = next
        }
        return outputs
    }
}

public extension View {
    @inline(never)
    func hidden() -> some View {
        modifier(_HiddenModifier())
    }
}

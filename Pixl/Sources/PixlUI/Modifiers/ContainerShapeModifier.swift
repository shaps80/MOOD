import Swift

private struct _ContainerShapeModifier<Container: Shape>: ViewModifier {
    typealias Body = Never

    let shape: Container

    static func _makeView(
        modifier: _GraphValue<Self>,
        inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs
    ) -> _ViewOutputs {
        let node = makeNode(modifier: modifier, inputs: inputs)
        var environment = inputs.environment
        environment.containerShape = node
        _ = body(
            inputs.graph,
            .init(
                graph: inputs.graph,
                parent: node,
                environment: environment,
                identity: inputs.identity
            )
        )
        return .init(node: node)
    }

    static func _makeViewList(
        modifier: _GraphValue<Self>,
        inputs: _ViewListInputs,
        body: @escaping (_Graph, _ViewListInputs) -> _ViewListOutputs
    ) -> _ViewListOutputs {
        let viewInputs = _ViewInputs(
            graph: inputs.graph,
            parent: inputs.parent,
            environment: inputs.environment,
            identity: inputs.identity
        )
        let node = makeNode(modifier: modifier, inputs: viewInputs)
        var environment = inputs.environment
        environment.containerShape = node
        _ = body(
            inputs.graph,
            .init(
                graph: inputs.graph,
                parent: node,
                environment: environment,
                identity: inputs.identity
            )
        )
        return .init(first: node, last: node, count: 1)
    }

    private static func makeNode(
        modifier: _GraphValue<Self>,
        inputs: _ViewInputs
    ) -> ViewGraph.NodeID {
        guard let shape = modifier.value.shape as? any _Shape else {
            preconditionFailure("containerShape requires a PixlUI-renderable Shape")
        }
        let payload = Int32(inputs.graph.containerShapes.count)
        inputs.graph.containerShapes.append(.init(shape: erase(shape)))
        return inputs.graph.appendNode(
            kind: .containerShape,
            payload: payload,
            parent: inputs.parent
        )
    }

    private static func erase(_ shape: any _Shape) -> _AnyShapeBox {
        func open<S: _Shape>(_ shape: S) -> _AnyShapeBox { _ShapeBox(shape) }
        return open(shape)
    }
}

extension View {
    public func containerShape<Container: Shape>(_ shape: Container) -> some View {
        modifier(_ContainerShapeModifier(shape: shape))
    }
}

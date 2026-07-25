import Swift

@usableFromInline func _makeShapeView<S: _Shape, Stroke: ShapeStyle>(
    shape: S,
    stroke: Stroke?,
    lineWidth: Float,
    inputs: _ViewInputs
) -> _ViewOutputs {
    let stroke = stroke.map {
        _ShapeStroke(
            style: _resolveShapeStyle($0, in: inputs.graph, environment: inputs.environment),
            lineWidth: lineWidth
        )
    }
    let record = _ShapeRecord(
        shape: _ShapeBox(shape),
        fill: inputs.environment.foregroundStyle,
        stroke: stroke
    )
    let payload = Int32(inputs.graph.shapes.count)
    inputs.graph.shapes.append(record)
    return .init(node: inputs.graph.appendNode(kind: .shape, payload: payload, parent: inputs.parent))
}

@usableFromInline struct _NoShapeStyle: ShapeStyle, Sendable { }

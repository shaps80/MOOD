import Swift

func _makeShapeView<S: _Shape, Stroke: ShapeStyle>(
    shape: S,
    stroke: Stroke?,
    lineWidth: Float,
    inputs: _ViewInputs
) -> _ViewOutputs {
    let fill = if stroke == nil {
        inputs.environment.foregroundStyle.resolveStyle(
            in: inputs.graph,
            environment: inputs.environment
        )
    } else {
        inputs.graph.internStyle(.color(.clear))
    }
    let stroke = stroke.map {
        _ShapeStroke(
            style: _resolveShapeStyle($0, in: inputs.graph, environment: inputs.environment),
            lineWidth: lineWidth
        )
    }
    let record = _ShapeRecord(
        shape: _ShapeBox(shape),
        fill: fill,
        stroke: stroke,
        containerShape: inputs.environment.containerShape
    )
    let payload = Int32(inputs.graph.shapes.count)
    inputs.graph.shapes.append(record)
    return .init(node: inputs.graph.appendNode(kind: .shape, payload: payload, parent: inputs.parent))
}

struct _NoShapeStyle: ShapeStyle, Sendable { }

import Swift

private struct _EnvironmentModifier<Value>: ViewModifier {
    typealias Body = Never

    let keyPath: WritableKeyPath<EnvironmentValues, Value>
    let value: Value

    static func _makeView(
        modifier: _GraphValue<Self>,
        inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs
    ) -> _ViewOutputs {
        var inputs = inputs
        inputs.environment[keyPath: modifier.value.keyPath] = modifier.value.value
        return body(inputs.graph, inputs)
    }

    static func _makeViewList(
        modifier: _GraphValue<Self>,
        inputs: _ViewListInputs,
        body: @escaping (_Graph, _ViewListInputs) -> _ViewListOutputs
    ) -> _ViewListOutputs {
        var inputs = inputs
        inputs.environment[keyPath: modifier.value.keyPath] = modifier.value.value
        return body(inputs.graph, inputs)
    }
}

extension View {
    public func environment<Value>(
        _ keyPath: WritableKeyPath<EnvironmentValues, Value>,
        _ value: Value
    ) -> some View {
        modifier(_EnvironmentModifier(keyPath: keyPath, value: value))
    }
}

import Swift

public struct _TintModifier: ViewModifier {
    public typealias Body = Never
    public var color: Color

    @inlinable public init(color: Color) { self.color = color }

    public static func _makeView(
        modifier: _GraphValue<Self>,
        inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs
    ) -> _ViewOutputs {
        var inputs = inputs
        inputs.environment.tint = .init(modifier.value.color)
        return body(inputs.graph, inputs)
    }

    public static func _makeViewList(
        modifier: _GraphValue<Self>,
        inputs: _ViewListInputs,
        body: @escaping (_Graph, _ViewListInputs) -> _ViewListOutputs
    ) -> _ViewListOutputs {
        var inputs = inputs
        inputs.environment.tint = .init(modifier.value.color)
        return body(inputs.graph, inputs)
    }
}

extension View {
    @inlinable public func tint(_ color: Color) -> some View {
        modifier(_TintModifier(color: color))
    }
}

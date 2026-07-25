import Swift

public protocol ViewModifier {
    associatedtype Body: View

    typealias Content = _ViewModifier_Content<Self>

    @ContentBuilder
    func body(content: Content) -> Body

    @_documentation(visibility: internal)
    static func _makeView(
        modifier: _GraphValue<Self>,
        inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs
    ) -> _ViewOutputs

    @_documentation(visibility: internal)
    static func _makeViewList(
        modifier: _GraphValue<Self>,
        inputs: _ViewListInputs,
        body: @escaping (_Graph, _ViewListInputs) -> _ViewListOutputs
    ) -> _ViewListOutputs
}

extension ViewModifier {
    public static func _makeView(
        modifier: _GraphValue<Self>,
        inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs
    ) -> _ViewOutputs {
        body(.init(), inputs)
    }

    public static func _makeViewList(
        modifier: _GraphValue<Self>,
        inputs: _ViewListInputs,
        body: @escaping (_Graph, _ViewListInputs) -> _ViewListOutputs
    ) -> _ViewListOutputs {
        body(.init(), inputs)
    }
}

extension ViewModifier where Body == Never {
    public func body(content: Content) -> Never { fatalError() }
}

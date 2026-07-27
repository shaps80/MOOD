import Swift

public struct AnyStyle<Configuration> {
    private let box: _AnyStyleBox<Configuration>

    public init<Style, Body: View>(
        _ style: Style,
        @ContentBuilder makeBody: @escaping (Style, Configuration) -> Body
    ) {
        box = _ConcreteAnyStyleBox(style: style, makeBody: makeBody)
    }

    public func makeBody(configuration: Configuration) -> some View {
        _ResolvedAnyStyle(box: box, configuration: configuration)
    }
}

private struct _ResolvedAnyStyle<Configuration>: View {
    typealias Body = Never

    let box: _AnyStyleBox<Configuration>
    let configuration: Configuration

    var body: Never { fatalError() }

    static func _makeView(
        view: _GraphValue<Self>,
        inputs: _ViewInputs
    ) -> _ViewOutputs {
        view.value.box.makeView(
            configuration: view.value.configuration,
            inputs: inputs
        )
    }
}

private class _AnyStyleBox<Configuration> {
    func makeView(
        configuration: Configuration,
        inputs: _ViewInputs
    ) -> _ViewOutputs {
        fatalError("Abstract style box cannot make a view")
    }
}

private final class _ConcreteAnyStyleBox<Style, Configuration, Body: View>:
    _AnyStyleBox<Configuration>
{
    private let style: Style
    private let makeBody: (Style, Configuration) -> Body

    init(
        style: Style,
        makeBody: @escaping (Style, Configuration) -> Body
    ) {
        self.style = style
        self.makeBody = makeBody
    }

    override func makeView(
        configuration: Configuration,
        inputs: _ViewInputs
    ) -> _ViewOutputs {
        let body = makeBody(style, configuration)
        return Body._makeView(
            view: .init(body, graph: inputs.graph),
            inputs: inputs
        )
    }
}

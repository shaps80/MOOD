import Swift

public struct StyleContent: View {
    public typealias Body = Never
    private let box: _StyleContentBox

    public init<Content: View>(_ content: Content) {
        box = _ConcreteStyleContentBox(content)
    }

    public var body: Never { fatalError() }

    public static func _makeView(
        view: _GraphValue<Self>,
        inputs: _ViewInputs
    ) -> _ViewOutputs {
        view.value.box.makeView(graph: view.graph, inputs: inputs)
    }

    public static func _makeViewList(
        view: _GraphValue<Self>,
        inputs: _ViewListInputs
    ) -> _ViewListOutputs {
        view.value.box.makeViewList(graph: view.graph, inputs: inputs)
    }
}

private class _StyleContentBox {
    func makeView(graph: _Graph, inputs: _ViewInputs) -> _ViewOutputs {
        fatalError("Abstract style content box cannot make a view")
    }

    func makeViewList(
        graph: _Graph,
        inputs: _ViewListInputs
    ) -> _ViewListOutputs {
        fatalError("Abstract style content box cannot make a view list")
    }
}

private final class _ConcreteStyleContentBox<Content: View>: _StyleContentBox {
    private let content: Content

    init(_ content: Content) {
        self.content = content
    }

    override func makeView(
        graph: _Graph,
        inputs: _ViewInputs
    ) -> _ViewOutputs {
        Content._makeView(view: .init(content, graph: graph), inputs: inputs)
    }

    override func makeViewList(
        graph: _Graph,
        inputs: _ViewListInputs
    ) -> _ViewListOutputs {
        Content._makeViewList(view: .init(content, graph: graph), inputs: inputs)
    }
}

import Swift

@frozen public struct ZStack<Content: View>: View {
    public let alignment: Alignment
    public let content: Content

    @inlinable public init(
        alignment: Alignment = .center,
        @ContentBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.content = content()
    }

    public var body: Never { fatalError() }

    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        _LayoutView<ZStackLayout, Content>._makeView(view: .init(.init(layout: .init(alignment: view.value.alignment), content: view.value.content), graph: view.graph), inputs: inputs)
    }
}

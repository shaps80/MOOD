import Swift

@frozen public struct HStack<Content: View>: View {
    public let alignment: VerticalAlignment
    public let spacing: Float?
    public let content: Content

    @inlinable public init(
        alignment: VerticalAlignment = .center,
        spacing: Float? = nil,
        @ContentBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public var body: Never { fatalError() }

    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        _LayoutView<HStackLayout, Content>._makeView(view: .init(.init(layout: .init(alignment: view.value.alignment, spacing: view.value.spacing), content: view.value.content), graph: view.graph), inputs: inputs)
    }
}

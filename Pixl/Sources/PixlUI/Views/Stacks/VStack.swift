import Swift

@frozen public struct VStack<Content: View>: View {
    public let alignment: HorizontalAlignment
    public let spacing: Float?
    public let content: Content

    @inlinable public init(
        alignment: HorizontalAlignment = .center,
        spacing: Float? = nil,
        @ContentBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public var body: Never { fatalError() }

    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        _LayoutView<VStackLayout, Content>._makeView(view: .init(.init(layout: .init(alignment: view.value.alignment, spacing: view.value.spacing), content: view.value.content), graph: view.graph), inputs: inputs)
    }
}

import Swift

@frozen public struct HStack<Content: View>: View {
    public let alignment: VerticalAlignment
    public let spacing: Double?
    public let content: Content

    @inlinable public init(
        alignment: VerticalAlignment = .center,
        spacing: Double? = nil,
        @ContentBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public var body: Never { fatalError() }
}

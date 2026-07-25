import Swift

@frozen public struct VStack<Content: View>: View {
    public let alignment: HorizontalAlignment
    public let spacing: Double?
    public let content: Content

    @inlinable public init(
        alignment: HorizontalAlignment = .center,
        spacing: Double? = nil,
        @ContentBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public var body: Never { fatalError() }
}

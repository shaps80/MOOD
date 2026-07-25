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
}

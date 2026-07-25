import Swift

@frozen public struct ModifiedContent<Content, Modifier> {
    public var content: Content
    public var modifier: Modifier

    @inlinable public init(content: Content, modifier: Modifier) {
        self.content = content
        self.modifier = modifier
    }
}

extension ModifiedContent: View where Content: View, Modifier: ViewModifier {
    public typealias Body = Never

    public var body: Never { fatalError() }
}

extension View {
    @inlinable public func modifier<Modifier: ViewModifier>(
        _ modifier: Modifier
    ) -> ModifiedContent<Self, Modifier> {
        .init(content: self, modifier: modifier)
    }
}

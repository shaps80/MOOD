import Swift

@frozen public struct _BackgroundModifier<Background: View>: ViewModifier {
    public typealias Body = Never

    public var background: Background
    public var alignment: Alignment

    @inlinable public init(
        background: Background,
        alignment: Alignment = .center
    ) {
        self.background = background
        self.alignment = alignment
    }
}

extension View {
    @inlinable public func background<Background: View>(
        alignment: Alignment = .center,
        @ContentBuilder content: () -> Background
    ) -> some View {
        modifier(
            _BackgroundModifier(
                background: content(),
                alignment: alignment
            )
        )
    }
}

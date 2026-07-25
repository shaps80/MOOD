import Swift

@frozen public struct _OverlayModifier<Overlay: View>: ViewModifier {
    public typealias Body = Never

    public var overlay: Overlay
    public var alignment: Alignment

    @inlinable public init(
        overlay: Overlay,
        alignment: Alignment = .center
    ) {
        self.overlay = overlay
        self.alignment = alignment
    }
}

extension View {
    @inlinable public func overlay<Overlay: View>(
        alignment: Alignment = .center,
        @ContentBuilder content: () -> Overlay
    ) -> some View {
        modifier(
            _OverlayModifier(
                overlay: content(),
                alignment: alignment
            )
        )
    }
}

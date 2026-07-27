import PixlUI

extension View {
    func sidebar(alignment: HorizontalAlignment = .trailing) -> some View {
        modifier(SidebarModifier(alignment: alignment))
    }
}

private struct SidebarModifier: ViewModifier {
    var alignment: HorizontalAlignment

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: 300, maxHeight: .infinity, alignment: .top)
            .background {
                Rectangle()
                    .foregroundStyle(.gray6.opacity(0.8))
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .init(
                    horizontal: alignment,
                    vertical: .center
                )
            )
            .padding()
    }
}

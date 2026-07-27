import PixlUI

extension View {
    func sidebar(alignment: HorizontalAlignment = .trailing) -> some View {
        modifier(SidebarModifier(alignment: alignment))
    }
}

private struct TestModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            Color.red
            content
        }
    }
}

private struct SidebarModifier: ViewModifier {
    var alignment: HorizontalAlignment

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: 350, maxHeight: .infinity, alignment: .top)
            .background {
                Rectangle()
                    .foregroundStyle(.black.opacity(0.4))
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

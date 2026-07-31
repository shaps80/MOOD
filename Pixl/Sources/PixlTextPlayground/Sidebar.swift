import SwiftUI

extension View {
    func sidebar<Content: View>(isPresented: Binding<Bool>, @ContentBuilder content: () -> Content) -> some View {
        modifier(
            SidebarModifier(
                isPresented: isPresented,
                wrapped: content()
            )
        )
    }
}

private struct SidebarModifier<Wrapped: View>: ViewModifier {
    @Binding var isPresented: Bool
    var wrapped: Wrapped

    func body(content: Content) -> some View {
        HStack {
            content

            Spacer()

            Form {
                wrapped
            }
            .toolbarTitleDisplayMode(.inline)
            .transition(.move(edge: .trailing).combined(with: .opacity))
            .frame(width: 300, alignment: .trailing)
            .scenePadding()
        }
    }
}

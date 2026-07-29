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
        content
            .overlay(alignment: .trailing) {
                ZStack {
                    if isPresented {
                        Form {
                            wrapped
                        }
                        .toolbarTitleDisplayMode(.inline)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: 300, maxHeight: .infinity)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .scenePadding()
                .toolbar {
                    Button("Toggle Panel", systemImage: "sidebar.right") {
                        withAnimation(.snappy) {
                            isPresented.toggle()
                        }
                    }
                }
            }
    }
}

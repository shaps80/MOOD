import SwiftUI

struct FittingScrollView<Content: View>: View {
    @State private var contentHeight = 0.0
    @ViewBuilder private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .onGeometryChange(for: Double.self) { proxy in
                    proxy.size.height
                } action: { height in
                    contentHeight = height
                }
        }
        .frame(
            idealHeight: contentHeight,
            maxHeight: contentHeight
        )
        .scrollBounceBehavior(.basedOnSize)
    }
}

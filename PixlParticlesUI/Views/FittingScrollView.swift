import SwiftUI

struct FittingScrollView<Content: View>: View {
    @ViewBuilder private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            content

            ScrollView {
                content
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

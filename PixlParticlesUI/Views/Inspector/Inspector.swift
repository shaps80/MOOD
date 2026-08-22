import SwiftUI
import PixlParticles
import PixlRenderer

struct Inspector<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        FittingScrollView {
            Divided {
                content
            }
            .frame(
                maxWidth: .infinity,
                alignment: .topLeading
            )
            .scenePadding()
            .padding(5)
        }
        .toggleStyle(.checkmark)
        .labeledContentStyle(.inspector)
        .focusable(false)
        .focusEffectDisabled(true)
        .clipShape(.rect(cornerRadius: 28))
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 28))
        .frame(maxWidth: 300)
    }
}

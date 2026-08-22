import SwiftUI

nonisolated public struct PanelView<ID, Content>: View, ~Sendable where ID: Hashable, Content: View {
    @Binding private var customization: PanelCustomization<ID>
    private let content: Content

    nonisolated public init<C>(
        customization: Binding<PanelCustomization<ID>> = .constant(.init()),
        @PanelContentBuilder<ID> content: () -> C
    ) where Content == PanelContentBuilder<ID>.Content<C>, C: PanelContent {
        _customization = customization
        self.content = PanelContentBuilder.Content(content())
    }

    @MainActor
    public var body: some View {
        GeometryReader { geometry in
            Group(subviews: content) { subviews in
                let orderedSubviews = subviews.ordered(by: customization)

                ZStack {
                    ForEach(orderedSubviews) { subview in
                        ContentView(
                            subview: subview,
                            containerSize: geometry.size,
                            customization: $customization
                        )
                    }
                }
            }
        }
    }
}

private enum PanelKind: String, Identifiable, Sendable {
    var id: String { rawValue }
    case properties
    case metrics
}

#Preview {
    @Previewable @State var customization: PanelCustomization<PanelKind> = .init()

    ZStack {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ).ignoresSafeArea()

        PanelView(customization: $customization) {
            Panel(id: .properties) {
                FittingScrollView {
                    Text("Hello")
                        .padding()
                }
            }
            .defaultPlacement(.bottomLeading)

            Panel(id: .metrics) {
                Text("Test")
                    .padding()
            }
            .defaultPlacement(.topTrailing)
        }
        .animation(.smooth.speed(2), value: customization)
        .scenePadding()
    }
    .frame(width: 800, height: 600)
}

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

import SwiftUI

nonisolated public struct PanelView<ID, Content>: View, ~Sendable where ID: Hashable & Codable & Sendable, Content: View {
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

                ZStack(alignment: .topLeading) {
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

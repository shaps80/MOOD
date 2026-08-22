import SwiftUI

nonisolated public struct PanelView<SelectionValue, Content>: View, ~Sendable where SelectionValue: Hashable, Content: View {
    @Binding private var selection: SelectionValue
    private let content: Content

    nonisolated public init<C>(
        selection: Binding<SelectionValue>,
        @PanelContentBuilder<SelectionValue> content: () -> C
    ) where Content == PanelContentBuilder<SelectionValue>.Content<C>, C: PanelContent {
        _selection = selection
        self.content = PanelContentBuilder.Content(content())
    }

    public var body: some View {
        VStack {
            ForEach(subviews: content) { subview in
                subview
            }
        }
    }
}

extension PanelView where SelectionValue == Int {
    nonisolated public init<C>(
        @PanelContentBuilder<Int> content: () -> C
    ) where Content == PanelContentBuilder<Int>.Content<C>, C: PanelContent {
        self.init(selection: .constant(0), content: content)
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        PanelView {
            Panel(value: 0) {
                Text("Hello")
            }

            Panel(value: 1) {
                Text("World")
            }
        }
        .scenePadding()
    }
    .frame(width: 800, height: 600)
}

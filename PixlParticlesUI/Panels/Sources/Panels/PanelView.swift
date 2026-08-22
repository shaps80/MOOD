import SwiftUI

nonisolated public struct PanelView<SelectionValue, Content>: View, ~Sendable where SelectionValue: Hashable, Content: View {
    @State private var internalSelection: SelectionValue
    @Binding private var customization: PanelCustomization
    private let externalSelection: Binding<SelectionValue>?
    private let content: Content

    private var selection: Binding<SelectionValue> {
        externalSelection ?? $internalSelection
    }

    nonisolated public init<C>(
        selection: Binding<SelectionValue>,
        customization: Binding<PanelCustomization> = .constant(.init()),
        @PanelContentBuilder<SelectionValue> content: () -> C
    ) where Content == PanelContentBuilder<SelectionValue>.Content<C>, C: PanelContent {
        _internalSelection = State(initialValue: selection.wrappedValue)
        _customization = customization
        externalSelection = selection
        self.content = PanelContentBuilder.Content(content())
    }

    public var body: some View {
        VStack {
            ForEach(subviews: content) { subview in
                let id = subview.containerValues.panelCustomizationID
                let isExplicitlyVisible = id.map {
                    customization[visibility: $0] == .visible
                } ?? false
                let isVisibleByDefault = subview.containerValues.panelDefaultVisibility != .hidden

                if isExplicitlyVisible || isVisibleByDefault {
                    subview
                }
            }
        }
    }
}

extension PanelView where SelectionValue == Int {
    nonisolated public init<C>(
        customization: Binding<PanelCustomization> = .constant(.init()),
        @PanelContentBuilder<Int> content: () -> C
    ) where Content == PanelContentBuilder<Int>.Content<C>, C: PanelContent {
        _internalSelection = State(initialValue: 0)
        _customization = customization
        externalSelection = nil
        self.content = PanelContentBuilder.Content(content())
    }
}

private enum PanelKind: String, Identifiable {
    var id: String { rawValue }
    case properties
    case metrics
}

#Preview {

    @Previewable @State var customization: PanelCustomization = .init()
    @Previewable @State var selection: PanelKind = .properties

    ZStack {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ).ignoresSafeArea()

        PanelView(selection: $selection, customization: $customization) {
            Panel(value: .properties) {
                Text("Hello")
            }

            Panel(value: .metrics) {
                Text("World")
                    .contentShape(.rect)
                    .onTapGesture {
                        print("Tapped")
                        customization[visibility: PanelKind.metrics.rawValue] = .hidden
                    }
            }
        }
        .scenePadding()
    }
    .frame(width: 800, height: 600)
}

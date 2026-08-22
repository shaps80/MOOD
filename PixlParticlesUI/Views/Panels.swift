import SwiftUI

struct Panels<Content: View>: View {
    @Binding var customization: PanelCustomization
    let content: Content

    init(customization: Binding<PanelCustomization>, @ViewBuilder content: () -> Content) {
        _customization = customization
        self.content = content()
    }

    var body: some View {
        ForEach(subviews: content) { subview in
            let id = subview.containerValues.panelId ?? String(describing: subview.id)

            subview
                .panelContent(
                    id: id,
                    placement: subview.containerValues.panelPlacement,
                    isPresented: .init(
                        get: { customization[visibility: id] != .hidden },
                        set: {
                            customization[visibility: id] = $0 ? .visible : .hidden
                        }
                    )) {
                        subview
                    }
        }
    }
}

extension ContainerValues {
    @Entry var panelId: String?
    @Entry var panelPlacement: UnitPoint = .trailing
}

#Preview {
    @Previewable @State var customization: PanelCustomization = .init()

    NavigationStack {
        ZStack {
            ContentView(document: .init())

            Panels(customization: $customization) {
                Text("Testing")
            }
        }
    }
    .frame(width: 800, height: 600)
}

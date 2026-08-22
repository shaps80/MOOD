import SwiftUI

struct PanelView<Panels: PanelContent>: View {
    var panels: [_Panel]

    var body: some View {
        VStack {
            ForEach(panels) { panel in
                AnyView(panel.content())
                    .id(panel.id)
            }
        }
    }
}

extension PanelView {
    init(@PanelBuilder panels: () -> Panels) {
        self.panels = Panels._makeContent(
            content: .init(panels()),
            inputs: .init()
        ).panels
    }
}

#Preview {
    PanelView {
        Panel(id: "hello") {
            Text("Hello")
        }
        .defaultAlignment(.leading)
        .defaultVisibilty(.hidden)
//        .customizationID("hello")

        Panel(id: "world") {
            Text("World")
        }
        .defaultAlignment(.trailing)
        .defaultVisibilty(.visible)
//        .customizationID("world")
    }
    .frame(width: 800, height: 600)
    .scenePadding()
}

import SwiftUI

struct _CustomizationIDPanelContent<Content> where Content: PanelContent {
    let content: Content
    let id: String

    nonisolated init(content: Content, id: String) {
        self.content = content
        self.id = id
    }
}

extension _CustomizationIDPanelContent: PanelContent {
    typealias PanelValue = Content.PanelValue

    var body: Self { self }

    func _panelView(_ inputs: _PanelInputs) -> some View {
        var inputs = inputs
        inputs.customizationID = id
        return content._panelView(inputs)
    }
}

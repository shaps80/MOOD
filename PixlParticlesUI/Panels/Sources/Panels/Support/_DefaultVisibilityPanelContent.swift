import SwiftUI

struct _DefaultVisibilityPanelContent<Content> where Content: PanelContent {
    let content: Content
    let visibility: Visibility

    nonisolated init(content: Content, visibility: Visibility) {
        self.content = content
        self.visibility = visibility
    }
}

extension _DefaultVisibilityPanelContent: PanelContent {
    typealias PanelValue = Content.PanelValue

    var body: Self { self }

    func _panelView(_ inputs: _PanelInputs) -> some View {
        var inputs = inputs
        inputs.defaultVisibility = visibility
        return content._panelView(inputs)
    }
}

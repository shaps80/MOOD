import SwiftUI

struct _DefaultPlacementPanelContent<Content> where Content: PanelContent {
    let content: Content
    let placement: UnitPoint

    nonisolated init(content: Content, placement: UnitPoint) {
        self.content = content
        self.placement = placement
    }
}

extension _DefaultPlacementPanelContent: PanelContent {
    typealias PanelValue = Content.PanelValue

    var body: Self { self }

    func _panelView(_ inputs: _PanelInputs) -> some View {
        var inputs = inputs
        inputs.defaultPlacement = placement
        return content._panelView(inputs)
    }
}

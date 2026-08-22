import SwiftUI

struct _PanelWidthContent<Content> where Content: PanelContent {
    let content: Content
    let widths: (min: CGFloat, ideal: CGFloat?, max: CGFloat?)

    nonisolated init(
        content: Content,
        widths: (min: CGFloat, ideal: CGFloat?, max: CGFloat?)
    ) {
        self.content = content
        self.widths = widths
    }
}

extension _PanelWidthContent: PanelContent {
    typealias PanelValue = Content.PanelValue

    var body: Self { self }

    func _panelView(_ inputs: _PanelInputs) -> some View {
        var inputs = inputs
        inputs.widths = widths
        return content._panelView(inputs)
    }
}

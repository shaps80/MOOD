import SwiftUI

struct _AnimatedPanelContent<Content> where Content: PanelContent {
    let content: Content
    let animation: Animation?

    nonisolated init(content: Content, animation: Animation?) {
        self.content = content
        self.animation = animation
    }
}

extension _AnimatedPanelContent: PanelContent {
    typealias PanelValue = Content.PanelValue

    var body: Self { self }

    func _panelView(_ inputs: _PanelInputs) -> some View {
        content
            ._panelView(inputs)
            .transaction { transaction in
                guard transaction.animation == nil else { return }
                transaction.animation = animation
            }
    }
}

import SwiftUI

// An ultra-simplified modifier
typealias _PanelModifier = (inout _PanelInputs) -> Void

extension ModifiedContent: PanelContent where Content: PanelContent, Modifier == _PanelModifier {
    typealias PanelBody = Never
    var panelBody: Never { fatalError() }

    static func _makeContent(content: _GraphValue<ModifiedContent<Content, Modifier>>, inputs: _PanelInputs) -> _PanelOutputs {
        var inputs = inputs
        content.value.modifier(&inputs)
        return Content._makeContent(content: .init(content.value.content), inputs: inputs)
    }
}

extension PanelContent {
    func modifier(_ transform: @escaping _PanelModifier) -> ModifiedContent<Self, _PanelModifier> {
        .init(content: self, modifier: transform)
    }
}

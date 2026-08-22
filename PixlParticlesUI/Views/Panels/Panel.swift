import SwiftUI

struct Panel<Content: View>: PanelContent {
    var id: String
    var widths: (CGFloat, CGFloat?, CGFloat?) = (0, nil, nil)
    var content: () -> Content

    var panelBody: Never { fatalError() }

    init(id: String, @ViewBuilder content: @escaping () -> Content) {
        self.id = id
        self.content = content
    }
}

extension Panel {
    nonisolated func width(_ width: CGFloat? = nil) -> Self {
        var copy = self
        if let width {
            copy.widths = (width, width, width)
        }
        return copy
    }

    nonisolated func width(min: CGFloat? = nil, ideal: CGFloat? = nil, max: CGFloat? = nil) -> Self {
        var copy = self
        copy.widths = (min ?? copy.widths.0, ideal, max)
        return copy
    }
}

extension Panel {
    static func _makeContent(content: _GraphValue<Self>, inputs: _PanelInputs) -> _PanelOutputs {
        .init(
            panels: [
                .init(
                    id: content.value.id,
                    widths: content.value.widths,
                    defaultAlignment: inputs.defaultAlignment,
                    defaultVisiblity: inputs.defaultVisiblity,
                    content: { content.value.content() }
                )
            ]
        )
    }
}

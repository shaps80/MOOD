import SwiftUI

protocol PanelContent {
    associatedtype PanelBody: PanelContent
    var panelBody: PanelBody { get }
    static func _makeContent(content: _GraphValue<Self>, inputs: _PanelInputs) -> _PanelOutputs
}

extension PanelContent {
    static func _makeContent(content: _GraphValue<Self>, inputs: _PanelInputs) -> _PanelOutputs {
        PanelBody._makeContent(
            content: .init(content.value.panelBody),
            inputs: inputs
        )
    }
}

extension Never: PanelContent {
    typealias PanelBody = Never
    var panelBody: Never { fatalError() }
}

@MainActor
extension PanelContent {
    func defaultVisibilty(_ visibility: Visibility) -> some PanelContent {
        modifier { $0.defaultVisiblity = visibility }
    }

    func defaultAlignment(_ alignment: UnitPoint) -> some PanelContent {
        modifier { $0.defaultAlignment = alignment }
    }
}

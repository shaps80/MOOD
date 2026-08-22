import SwiftUI

public struct PanelTupleContent<PanelValue, each Content> where PanelValue: Hashable, repeat each Content: PanelContent {
    let content: (repeat each Content)

    init(_ content: repeat each Content) {
        self.content = (repeat each content)
    }
}

extension PanelTupleContent: PanelContent {
    public var body: Self { self }

    public var _panelView: TupleView<(repeat (each Content)._PanelView)> {
        TupleView((repeat (each content)._panelView))
    }
}

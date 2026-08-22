import SwiftUI

@preconcurrency @MainActor public protocol PanelContent<PanelValue> {
    associatedtype PanelValue: Hashable where PanelValue == Body.PanelValue
    associatedtype Body: PanelContent
    associatedtype _PanelView: View = _PanelContentBodyAdaptor<Self>

    @PanelContentBuilder<PanelValue> @MainActor @preconcurrency var body: Body { get }
    @MainActor @preconcurrency var _panelView: _PanelView { get }
}

public extension PanelContent where _PanelView == _PanelContentBodyAdaptor<Self> {
    var _panelView: _PanelContentBodyAdaptor<Self> {
        _PanelContentBodyAdaptor(content: self)
    }
}

public struct _PanelContentBodyAdaptor<Content: PanelContent>: View {
    let content: Content

    public var body: some View {
        content.body._panelView
    }
}

public extension PanelContent {
    nonisolated func defaultVisibility(_ visibility: Visibility) -> some PanelContent<PanelValue> {
        // LLM to implement
    }

    nonisolated func defaultPlacement(_ placement: UnitPoint) -> some PanelContent<PanelValue> {
        // LLM to implement
    }
}

import SwiftUI

@preconcurrency @MainActor public protocol PanelContent<PanelValue> {
    associatedtype PanelValue: Hashable where PanelValue == Body.PanelValue
    associatedtype Body: PanelContent
    associatedtype _PanelView: View = _PanelContentBodyAdaptor<Self>

    @PanelContentBuilder<PanelValue> @MainActor @preconcurrency var body: Body { get }
    @MainActor @preconcurrency func _panelView(_ inputs: _PanelInputs) -> _PanelView
}

public extension PanelContent where _PanelView == _PanelContentBodyAdaptor<Self> {
    func _panelView(_ inputs: _PanelInputs) -> _PanelContentBodyAdaptor<Self> {
        _PanelContentBodyAdaptor(content: self, inputs: inputs)
    }
}

public struct _PanelContentBodyAdaptor<Content: PanelContent>: View {
    let content: Content
    let inputs: _PanelInputs

    public var body: some View {
        content.body._panelView(inputs)
    }
}

public extension PanelContent {
    nonisolated func defaultVisibility(_ visibility: Visibility) -> some PanelContent<PanelValue> {
        _DefaultVisibilityPanelContent(content: self, visibility: visibility)
    }

    nonisolated func defaultPlacement(_ placement: UnitPoint) -> some PanelContent<PanelValue> {
        _DefaultPlacementPanelContent(content: self, placement: placement)
    }

    nonisolated func width(_ width: CGFloat) -> some PanelContent<PanelValue> {
        _PanelWidthContent(
            content: self,
            widths: (min: width, ideal: width, max: width)
        )
    }

    nonisolated func width(
        min: CGFloat = 0,
        ideal: CGFloat? = nil,
        max: CGFloat? = nil
    ) -> some PanelContent<PanelValue> {
        _PanelWidthContent(
            content: self,
            widths: (min: min, ideal: ideal, max: max)
        )
    }
}

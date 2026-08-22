import SwiftUI

public struct _PanelInputs: Sendable {
    var customizationID: String?
    var defaultVisibility: Visibility = .automatic
    var defaultPlacement: UnitPoint = .center
    var widths: (min: CGFloat, ideal: CGFloat?, max: CGFloat?) = (0, nil, nil)

    public init() { }
}

import SwiftUI

public struct _PanelInputs: Sendable {
    var customizationID: String?
    var defaultVisibility: Visibility = .automatic
    var defaultPlacement: UnitPoint = .center
    var widths: (min: CGFloat?, ideal: CGFloat?, max: CGFloat?) = (nil, nil, nil)

    public init() { }
}

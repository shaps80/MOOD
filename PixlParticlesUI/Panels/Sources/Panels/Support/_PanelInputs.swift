import SwiftUI

public struct _PanelInputs: Sendable {
    var defaultVisibility: Visibility = .automatic
    var defaultPlacement: UnitPoint = .center
    var widths: (min: CGFloat?, ideal: CGFloat?, max: CGFloat?) = (nil, nil, nil)
    var animation: Animation? = .smooth.speed(2)

    public init() { }
}

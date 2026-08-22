import SwiftUI

extension ContainerValues {
    @Entry var panelDefaultVisibility: Visibility = .hidden
    @Entry var panelDefaultPlacement: UnitPoint = .center
    @Entry var panelWidths: (min: CGFloat?, ideal: CGFloat?, max: CGFloat?) = (nil, nil, nil)
}

import SwiftUI

extension ContainerValues {
    @Entry var panelCustomizationID: String?
    @Entry var panelDefaultVisibility: Visibility = .hidden
    @Entry var panelDefaultPlacement: UnitPoint = .center
    @Entry var panelWidths: (min: CGFloat, ideal: CGFloat?, max: CGFloat?) = (0, nil, nil)
}

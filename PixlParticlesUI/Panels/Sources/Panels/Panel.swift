import SwiftUI

public struct Panel<Value, Content> where Value: Hashable, Content: View {
    let value: Value
    let content: Content

    nonisolated public init(
        value: Value,
        @ContentBuilder content: () -> Content
    ) {
        self.value = value
        self.content = content()
    }
}

extension Panel: PanelContent {
    public typealias PanelValue = Value

    public var body: Self { self }

    public func _panelView(_ inputs: _PanelInputs) -> some View {
        content
            .tag(value)
            .containerValue(\.panelCustomizationID, inputs.customizationID)
            .containerValue(\.panelDefaultVisibility, inputs.defaultVisibility)
            .containerValue(\.panelDefaultPlacement, inputs.defaultPlacement)
            .containerValue(\.panelWidths, inputs.widths)
    }
}

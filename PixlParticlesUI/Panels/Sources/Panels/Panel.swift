import SwiftUI

public struct Panel<ID, Content> where ID: Hashable & Sendable, Content: View {
    let id: ID
    let content: Content

    nonisolated public init(
        id: ID,
        @ContentBuilder content: () -> Content
    ) {
        self.id = id
        self.content = content()
    }
}

extension Panel: PanelContent {
    public typealias PanelValue = ID

    public var body: Self { self }

    public func _panelView(_ inputs: _PanelInputs) -> some View {
        content
            .id(id)
            .tag(id)
            .containerValue(\.panelDefaultVisibility, inputs.defaultVisibility)
            .containerValue(\.panelDefaultPlacement, inputs.defaultPlacement)
            .containerValue(\.panelWidths, inputs.widths)
    }
}

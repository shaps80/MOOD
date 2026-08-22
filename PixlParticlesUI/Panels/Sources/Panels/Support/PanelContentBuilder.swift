import SwiftUI

@resultBuilder
public struct PanelContentBuilder<PanelValue>: ~Sendable where PanelValue: Hashable {
    nonisolated public struct Content<C>: View, ~Sendable where C: PanelContent {
        let content: C

        init(_ content: C) {
            self.content = content
        }

        @MainActor public var body: some View {
            content._panelView(_PanelInputs())
        }
    }
}

public extension PanelContentBuilder {
    static func buildExpression<Content>(_ content: Content) -> Content
    where Content: PanelContent<PanelValue> {
        content
    }

    static func buildBlock<Content>(_ content: Content) -> Content
    where Content: PanelContent<PanelValue> {
        content
    }

    static func buildBlock<each Content>(
        _ content: repeat each Content
    ) -> PanelTupleContent<PanelValue, repeat each Content>
    where repeat each Content: PanelContent {
        PanelTupleContent(repeat each content)
    }
}

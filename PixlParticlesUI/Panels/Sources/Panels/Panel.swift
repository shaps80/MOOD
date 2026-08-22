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

    public var _panelView: some View {
        content
            .tag(value)
    }
}

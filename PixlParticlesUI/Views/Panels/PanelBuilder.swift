import SwiftUI

@resultBuilder
struct PanelBuilder {
    static func buildBlock<Content: View>(_ panel: Panel<Content>) -> Panel<Content> {
        panel
    }

    static func buildBlock<P0, P1>(_ p0: P0, _ p1: P1) -> TuplePanelContent<(P0, P1)> {
        .init((p0, p1))
    }

    static func buildBlock<P0, P1, P2>(_ p0: P0, _ p1: P1, _ p2: P2) -> TuplePanelContent<(P0, P1, P2)> {
        .init((p0, p1, p2))
    }

    static func buildBlock<P0, P1, P2, P3>(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3) -> TuplePanelContent<(P0, P1, P2, P3)> {
        .init((p0, p1, p2, p3))
    }

    static func buildBlock<P0, P1, P2, P3, P4>(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4) -> TuplePanelContent<(P0, P1, P2, P3, P4)> {
        .init((p0, p1, p2, p3, p4))
    }

    static func buildBlock<P0, P1, P2, P3, P4, P5>(_ p0: P0, _ p1: P1, _ p2: P2, _ p3: P3, _ p4: P4, _ p5: P5) -> TuplePanelContent<(P0, P1, P2, P3, P4, P5)> {
        .init((p0, p1, p2, p3, p4, p5))
    }
}

struct TuplePanelContent<T>: PanelContent {
    var panelBody: Never { fatalError() }
    var value: T

    @inlinable init(_ value: T) {
        self.value = value
    }

    static func _makeContent(content: _GraphValue<TuplePanelContent<T>>, inputs: _PanelInputs) -> _PanelOutputs {
        var panels: [_Panel] = []
        for child in Mirror(reflecting: content.value.value).children {
            let content = child.value as! any PanelContent
            let outputs = _makePanel(panel: content, inputs: inputs)
            panels.append(contentsOf: outputs.panels)
        }
        return .init(panels: panels)
    }

    private static func _makePanel<Panel: PanelContent>(
        panel: Panel,
        inputs: _PanelInputs
    ) -> _PanelOutputs {
        Panel._makeContent(content: .init(panel), inputs: inputs)
    }
}

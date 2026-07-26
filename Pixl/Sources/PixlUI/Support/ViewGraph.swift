import PixlGraphics
import Swift

package struct ViewGraph {
    package struct StyleID: Hashable, Sendable {
        package let rawValue: Int32
        @inlinable package init(rawValue: Int32) { self.rawValue = rawValue }
        package static let invalid = Self(rawValue: -1)
    }

    package enum ResolvedStyle: Hashable, Sendable {
        case color(Color)
    }

    package struct NodeID: Hashable, Sendable {
        package let rawValue: Int32

        @inlinable package init(rawValue: Int32) {
            self.rawValue = rawValue
        }

        package static let invalid = NodeID(rawValue: -1)
        package var isValid: Bool { rawValue >= 0 }
    }

    package struct Node: Sendable {
        package enum Kind: String, Sendable {
            case empty
            case group
            case layout
            case primitive
            case composition
            case shape
        }

        package let kind: Kind
        package let payload: Int32
        package let parent: NodeID
        package internal(set) var firstChild: NodeID = .invalid
        package internal(set) var lastChild: NodeID = .invalid
        package internal(set) var nextSibling: NodeID = .invalid
    }

    package struct TextRecord: Sendable {
        package let content: String
        package let foregroundStyle: StyleID
    }

    package enum PrimitiveRecord: Sendable {
        case text(TextRecord)
        case fill(StyleID)
        case spacer(minLength: Float?)
        case divider
    }

    package struct CompositionRecord: Sendable {
        package enum Order: Sendable { case background, overlay }
        package let order: Order
        package let alignment: Alignment
    }

    package struct LayoutRecord: @unchecked Sendable { let box: _AnyLayoutBox }

    package let nodes: ContiguousArray<Node>
    package let primitives: ContiguousArray<PrimitiveRecord>
    package let compositions: ContiguousArray<CompositionRecord>
    package let styles: ContiguousArray<ResolvedStyle>
    package let layouts: ContiguousArray<LayoutRecord>
    package let shapes: ContiguousArray<_ShapeRecord>
    package let children: ContiguousArray<NodeID>
    package let childRanges: ContiguousArray<Range<Int>>

    package static func build<Root: View>(
        @ContentBuilder content: () -> Root
    ) -> ViewGraphRoot<Root> {
        build(content(), displayScale: 1)
    }

    static func build<Root: View>(
        _ value: Root,
        displayScale: Float
    ) -> ViewGraphRoot<Root> {
        precondition(
            displayScale.isFinite && displayScale > 0,
            "displayScale must be finite and greater than zero"
        )
        let graph = _Graph()
        let foregroundStyle = graph.internStyle(.color(.primary))
        let tint = graph.internStyle(.color(.orange))
        let root = _GraphValue(value, graph: graph)
        _ = Root._makeView(
            view: root,
            inputs: .init(
                graph: graph,
                parent: .invalid,
                environment: .init(
                    displayScale: displayScale,
                    foregroundStyle: foregroundStyle,
                    tint: tint
                )
            )
        )
        return .init(value: value, graphValue: root, graph: graph.snapshot())
    }
}

package struct ViewGraphRoot<Root: View>: CustomStringConvertible {
    package let value: Root
    package let graphValue: _GraphValue<Root>
    package let graph: ViewGraph

    package var description: String { graph.description }

    package func layout(in size: Size, displayScale: Float = 1) -> ViewLayout {
        graph.layout(in: size, displayScale: displayScale)
    }
}

extension ViewGraph: CustomStringConvertible {
    package var description: String {
        guard !nodes.isEmpty else { return "<empty>" }
        var result = ""
        var root = NodeID(rawValue: 0)
        while root.isValid {
            appendDescription(of: root, prefix: "", isLast: true, isRoot: true, to: &result)
            root = nodes[Int(root.rawValue)].nextSibling
        }
        if result.last == "\n" { result.removeLast() }
        return result
    }

    private func appendDescription(
        of id: NodeID,
        prefix: String,
        isLast: Bool,
        isRoot: Bool,
        to result: inout String
    ) {
        let node = nodes[Int(id.rawValue)]
        result += prefix
        if !isRoot { result += isLast ? "└─ " : "├─ " }
        result += label(for: node)
        result += "\n"

        var child = node.firstChild
        let childPrefix = prefix + (isRoot ? "" : (isLast ? "   " : "│  "))
        while child.isValid {
            let next = nodes[Int(child.rawValue)].nextSibling
            appendDescription(
                of: child,
                prefix: childPrefix,
                isLast: !next.isValid,
                isRoot: false,
                to: &result
            )
            child = next
        }
    }

    private func label(for node: Node) -> String {
        switch node.kind {
        case .empty:
            return "EmptyView"
        case .group:
            return "TupleContent"
        case .layout:
            return layouts[Int(node.payload)].box.debugName
        case .primitive:
            switch primitives[Int(node.payload)] {
            case .text(let text): return "Text(\(String(reflecting: text.content)))"
            case .fill: return "Color"
            case .spacer: return "Spacer"
            case .divider: return "Divider"
            }
        case .composition:
            switch compositions[Int(node.payload)].order {
            case .background: return "Background"
            case .overlay: return "Overlay"
            }
        case .shape:
            return shapes[Int(node.payload)].stroke == nil ? "Rectangle.fill" : "Rectangle.fill+stroke"
        }
    }
}

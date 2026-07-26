import PixlGraphics
import Swift

public struct ViewGraph {
    public struct StyleID: Hashable, Sendable {
        public let rawValue: Int32
        @inlinable public init(rawValue: Int32) { self.rawValue = rawValue }
        public static let invalid = Self(rawValue: -1)
    }

    public enum ResolvedStyle: Hashable, Sendable {
        case color(Color)
    }

    public struct NodeID: Hashable, Sendable {
        public let rawValue: Int32

        @inlinable public init(rawValue: Int32) {
            self.rawValue = rawValue
        }

        public static let invalid = NodeID(rawValue: -1)
        public var isValid: Bool { rawValue >= 0 }
    }

    public struct Node: Sendable {
        public enum Kind: String, Sendable {
            case empty
            case group
            case layout
            case primitive
            case composition
            case shape
        }

        public let kind: Kind
        public let payload: Int32
        public let parent: NodeID
        public internal(set) var firstChild: NodeID = .invalid
        public internal(set) var lastChild: NodeID = .invalid
        public internal(set) var nextSibling: NodeID = .invalid
    }

    public struct TextRecord: Sendable {
        public let content: String
        public let foregroundStyle: StyleID
    }

    public enum PrimitiveRecord: Sendable {
        case text(TextRecord)
        case fill(StyleID)
        case spacer(minLength: Float?)
        case divider
    }

    public struct CompositionRecord: Sendable {
        public enum Order: Sendable { case background, overlay }
        public let order: Order
        public let alignment: Alignment
    }

    @usableFromInline struct LayoutRecord: @unchecked Sendable { let box: _AnyLayoutBox }

    public let nodes: ContiguousArray<Node>
    public let primitives: ContiguousArray<PrimitiveRecord>
    public let compositions: ContiguousArray<CompositionRecord>
    public let styles: ContiguousArray<ResolvedStyle>
    @usableFromInline let layouts: ContiguousArray<LayoutRecord>
    @usableFromInline let shapes: ContiguousArray<_ShapeRecord>
    @usableFromInline let children: ContiguousArray<NodeID>
    @usableFromInline let childRanges: ContiguousArray<Range<Int>>

    public static func build<Root: View>(
        @ContentBuilder content: () -> Root
    ) -> ViewGraphRoot<Root> {
        build(content(), displayScale: 1)
    }

    @usableFromInline static func build<Root: View>(
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

public struct ViewGraphRoot<Root: View>: CustomStringConvertible {
    public let value: Root
    public let graphValue: _GraphValue<Root>
    public let graph: ViewGraph

    public var description: String { graph.description }

    public func layout(in size: Size, displayScale: Float = 1) -> ViewLayout {
        graph.layout(in: size, displayScale: displayScale)
    }
}

extension ViewGraph: CustomStringConvertible {
    public var description: String {
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

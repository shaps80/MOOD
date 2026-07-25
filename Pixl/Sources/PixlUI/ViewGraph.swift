import Swift

public struct ViewGraph {
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
            case text
            case verticalStack
            case horizontalStack
            case depthStack
            case background
            case overlay
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
    }

    public struct StackRecord: Sendable {
        public enum Axis: Sendable {
            case horizontal
            case vertical
            case depth
        }

        public let axis: Axis
        public let spacing: Double?
        public let horizontalAlignment: HorizontalAlignment?
        public let verticalAlignment: VerticalAlignment?
        public let alignment: Alignment?
    }

    public struct LayerRecord: Sendable {
        public let alignment: Alignment
    }

    public let nodes: ContiguousArray<Node>
    public let texts: ContiguousArray<TextRecord>
    public let stacks: ContiguousArray<StackRecord>
    public let layers: ContiguousArray<LayerRecord>

    public static func build<Root: View>(
        @ContentBuilder content: () -> Root
    ) -> ViewGraphRoot<Root> {
        let value = content()
        let graph = _Graph()
        let root = _GraphValue(value, graph: graph)
        _ = Root._makeView(
            view: root,
            inputs: .init(graph: graph, parent: .invalid)
        )
        return .init(value: value, graphValue: root, graph: graph.snapshot())
    }
}

public struct ViewGraphRoot<Root: View>: CustomStringConvertible {
    public let value: Root
    public let graphValue: _GraphValue<Root>
    public let graph: ViewGraph

    public var description: String { graph.description }
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
        case .text:
            return "Text(\(String(reflecting: texts[Int(node.payload)].content)))"
        case .verticalStack:
            return "VStack"
        case .horizontalStack:
            return "HStack"
        case .depthStack:
            return "ZStack"
        case .background:
            return "Background"
        case .overlay:
            return "Overlay"
        case .empty:
            return "EmptyView"
        case .group:
            return "TupleContent"
        }
    }
}

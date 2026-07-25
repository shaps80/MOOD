import Swift

@_documentation(visibility: internal)
public struct _GraphValue<Value> {
    public let value: Value
    @usableFromInline let graph: _Graph

    @usableFromInline
    init(_ value: Value, graph: _Graph) {
        self.value = value
        self.graph = graph
    }
}

@_documentation(visibility: internal)
public final class _Graph {
    @usableFromInline var nodes: ContiguousArray<ViewGraph.Node> = []
    @usableFromInline var primitives: ContiguousArray<ViewGraph.PrimitiveRecord> = []
    @usableFromInline var compositions: ContiguousArray<ViewGraph.CompositionRecord> = []
    @usableFromInline var styles: ContiguousArray<ViewGraph.ResolvedStyle> = []
    @usableFromInline var styleIDs: [ViewGraph.ResolvedStyle: ViewGraph.StyleID] = [:]
    @usableFromInline var layouts: ContiguousArray<ViewGraph.LayoutRecord> = []

    @usableFromInline init() { }

    @usableFromInline
    func internStyle(_ style: ViewGraph.ResolvedStyle) -> ViewGraph.StyleID {
        if let id = styleIDs[style] { return id }
        let id = ViewGraph.StyleID(rawValue: Int32(styles.count))
        styles.append(style)
        styleIDs[style] = id
        return id
    }

    @usableFromInline
    func appendNode(
        kind: ViewGraph.Node.Kind,
        payload: Int32 = -1,
        parent: ViewGraph.NodeID
    ) -> ViewGraph.NodeID {
        let id = ViewGraph.NodeID(rawValue: Int32(nodes.count))
        nodes.append(.init(kind: kind, payload: payload, parent: parent))

        guard parent.isValid else { return id }
        let parentIndex = Int(parent.rawValue)
        if nodes[parentIndex].firstChild.isValid {
            nodes[Int(nodes[parentIndex].lastChild.rawValue)].nextSibling = id
        } else {
            nodes[parentIndex].firstChild = id
        }
        nodes[parentIndex].lastChild = id
        return id
    }

    @usableFromInline
    func snapshot() -> ViewGraph {
        var children: ContiguousArray<ViewGraph.NodeID> = []
        var ranges: ContiguousArray<Range<Int>> = []
        ranges.reserveCapacity(nodes.count)
        for node in nodes {
            let start = children.count
            var child = node.firstChild
            while child.isValid { children.append(child); child = nodes[Int(child.rawValue)].nextSibling }
            ranges.append(start..<children.count)
        }
        return .init(nodes: nodes, primitives: primitives, compositions: compositions, styles: styles, layouts: layouts, children: children, childRanges: ranges)
    }
}

@_documentation(visibility: internal)
public struct _ViewInputs {
    @usableFromInline let graph: _Graph
    @usableFromInline let parent: ViewGraph.NodeID
    @usableFromInline var environment: EnvironmentValues
    @usableFromInline let modifierBody: ((_Graph, _ViewInputs) -> _ViewOutputs)?
    @usableFromInline let modifierBodyList: ((_Graph, _ViewListInputs) -> _ViewListOutputs)?

    @usableFromInline init(
        graph: _Graph,
        parent: ViewGraph.NodeID,
        environment: EnvironmentValues,
        modifierBody: ((_Graph, _ViewInputs) -> _ViewOutputs)? = nil,
        modifierBodyList: ((_Graph, _ViewListInputs) -> _ViewListOutputs)? = nil
    ) {
        self.graph = graph
        self.parent = parent
        self.environment = environment
        self.modifierBody = modifierBody
        self.modifierBodyList = modifierBodyList
    }
}

@_documentation(visibility: internal)
public struct _ViewOutputs {
    public let node: ViewGraph.NodeID

    @usableFromInline init(node: ViewGraph.NodeID) {
        self.node = node
    }
}

@_documentation(visibility: internal)
public struct _ViewListInputs {
    @usableFromInline let graph: _Graph
    @usableFromInline let parent: ViewGraph.NodeID
    @usableFromInline var environment: EnvironmentValues
    @usableFromInline let modifierBody: ((_Graph, _ViewListInputs) -> _ViewListOutputs)?
    @usableFromInline let modifierBodyView: ((_Graph, _ViewInputs) -> _ViewOutputs)?

    @usableFromInline init(
        graph: _Graph,
        parent: ViewGraph.NodeID,
        environment: EnvironmentValues,
        modifierBody: ((_Graph, _ViewListInputs) -> _ViewListOutputs)? = nil,
        modifierBodyView: ((_Graph, _ViewInputs) -> _ViewOutputs)? = nil
    ) {
        self.graph = graph
        self.parent = parent
        self.environment = environment
        self.modifierBody = modifierBody
        self.modifierBodyView = modifierBodyView
    }
}

@_documentation(visibility: internal)
public struct _ViewListOutputs {
    public let first: ViewGraph.NodeID
    public let last: ViewGraph.NodeID
    public let count: Int

    @usableFromInline
    init(first: ViewGraph.NodeID = .invalid, last: ViewGraph.NodeID = .invalid, count: Int = 0) {
        self.first = first
        self.last = last
        self.count = count
    }
}

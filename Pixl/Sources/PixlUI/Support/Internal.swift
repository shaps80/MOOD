import Swift

@_documentation(visibility: internal)
public struct _GraphValue<Value> {
    public let value: Value
    let graph: _Graph

        init(_ value: Value, graph: _Graph) {
        self.value = value
        self.graph = graph
    }
}

@_documentation(visibility: internal)
public final class _Graph {
    let stateStore: _StateStore
    var nodes: ContiguousArray<ViewGraph.Node> = []
    var primitives: ContiguousArray<ViewGraph.PrimitiveRecord> = []
    var compositions: ContiguousArray<ViewGraph.CompositionRecord> = []
    var styles: ContiguousArray<ViewGraph.ResolvedStyle> = []
    var styleIDs: [ViewGraph.ResolvedStyle: ViewGraph.StyleID] = [:]
    var layouts: ContiguousArray<ViewGraph.LayoutRecord> = []
    var shapes: ContiguousArray<_ShapeRecord> = []

    init(stateStore: _StateStore) {
        self.stateStore = stateStore
    }

        func internStyle(_ style: ViewGraph.ResolvedStyle) -> ViewGraph.StyleID {
        if let id = styleIDs[style] { return id }
        let id = ViewGraph.StyleID(rawValue: Int32(styles.count))
        styles.append(style)
        styleIDs[style] = id
        return id
    }

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
        return .init(nodes: nodes, primitives: primitives, compositions: compositions, styles: styles, layouts: layouts, shapes: shapes, children: children, childRanges: ranges)
    }
}

@_documentation(visibility: internal)
public struct _ViewInputs {
    let graph: _Graph
    let parent: ViewGraph.NodeID
    var environment: EnvironmentValues
    let identity: _ViewIdentity
    let modifierBody: ((_Graph, _ViewInputs) -> _ViewOutputs)?
    let modifierBodyList: ((_Graph, _ViewListInputs) -> _ViewListOutputs)?

    init(
        graph: _Graph,
        parent: ViewGraph.NodeID,
        environment: EnvironmentValues,
        identity: _ViewIdentity = .root,
        modifierBody: ((_Graph, _ViewInputs) -> _ViewOutputs)? = nil,
        modifierBodyList: ((_Graph, _ViewListInputs) -> _ViewListOutputs)? = nil
    ) {
        self.graph = graph
        self.parent = parent
        self.environment = environment
        self.identity = identity
        self.modifierBody = modifierBody
        self.modifierBodyList = modifierBodyList
    }

    func withIdentity(_ identity: _ViewIdentity) -> Self {
        .init(
            graph: graph,
            parent: parent,
            environment: environment,
            identity: identity,
            modifierBody: modifierBody,
            modifierBodyList: modifierBodyList
        )
    }
}

@_documentation(visibility: internal)
public struct _ViewOutputs {
    package let node: ViewGraph.NodeID

    init(node: ViewGraph.NodeID) {
        self.node = node
    }
}

@_documentation(visibility: internal)
public struct _ViewListInputs {
    let graph: _Graph
    let parent: ViewGraph.NodeID
    var environment: EnvironmentValues
    let identity: _ViewIdentity
    let modifierBody: ((_Graph, _ViewListInputs) -> _ViewListOutputs)?
    let modifierBodyView: ((_Graph, _ViewInputs) -> _ViewOutputs)?

    init(
        graph: _Graph,
        parent: ViewGraph.NodeID,
        environment: EnvironmentValues,
        identity: _ViewIdentity = .root,
        modifierBody: ((_Graph, _ViewListInputs) -> _ViewListOutputs)? = nil,
        modifierBodyView: ((_Graph, _ViewInputs) -> _ViewOutputs)? = nil
    ) {
        self.graph = graph
        self.parent = parent
        self.environment = environment
        self.identity = identity
        self.modifierBody = modifierBody
        self.modifierBodyView = modifierBodyView
    }

    func withIdentity(_ identity: _ViewIdentity) -> Self {
        .init(
            graph: graph,
            parent: parent,
            environment: environment,
            identity: identity,
            modifierBody: modifierBody,
            modifierBodyView: modifierBodyView
        )
    }
}

@_documentation(visibility: internal)
public struct _ViewListOutputs {
    package let first: ViewGraph.NodeID
    package let last: ViewGraph.NodeID
    public let count: Int

        init(first: ViewGraph.NodeID = .invalid, last: ViewGraph.NodeID = .invalid, count: Int = 0) {
        self.first = first
        self.last = last
        self.count = count
    }
}

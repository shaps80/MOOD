import Swift

@frozen public struct ForEach<Data, ID, Content>
where Data: RandomAccessCollection, ID: Hashable, Content: View {
    public let data: Data
    @usableFromInline let id: KeyPath<Data.Element, ID>
    public let content: (Data.Element) -> Content

    @inlinable public init(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        @ContentBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.id = id
        self.content = content
    }
}

extension ForEach where Data.Element: Identifiable, ID == Data.Element.ID {
    @inlinable public init(
        _ data: Data,
        @ContentBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.init(data, id: \.id, content: content)
    }
}

extension ForEach: View {
    public typealias Body = Never

    public var body: Never { fatalError() }

    public static func _makeView(
        view: _GraphValue<Self>,
        inputs: _ViewInputs
    ) -> _ViewOutputs {
        let node = inputs.graph.appendNode(kind: .group, parent: inputs.parent)
        _ = _makeViewList(
            view: view,
            inputs: .init(
                graph: inputs.graph,
                parent: node,
                environment: inputs.environment,
                identity: inputs.identity
            )
        )
        return .init(node: node)
    }

    public static func _makeViewList(
        view: _GraphValue<Self>,
        inputs: _ViewListInputs
    ) -> _ViewListOutputs {
        var first = ViewGraph.NodeID.invalid
        var last = ViewGraph.NodeID.invalid
        var count = 0
        var seen: Set<ID> = []

        for element in view.value.data {
            let id = element[keyPath: view.value.id]
            if !seen.insert(id).inserted {
                print(
                    "\(String(describing: Self.self)): the ID \(id) occurs multiple "
                        + "times within the collection, this will give undefined results!"
                )
            }

            let output = Content._makeViewList(
                view: .init(view.value.content(element), graph: view.graph),
                inputs: inputs.withIdentity(inputs.identity.explicit(id))
            )
            if !first.isValid { first = output.first }
            if output.last.isValid { last = output.last }
            count += output.count
        }

        return .init(first: first, last: last, count: count)
    }
}

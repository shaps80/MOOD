import Swift

public protocol View {
    associatedtype Body: View
    @ContentBuilder
    var body: Body { get }

    @_documentation(visibility: internal)
    static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs

    @_documentation(visibility: internal)
    static func _makeViewList(view: _GraphValue<Self>, inputs: _ViewListInputs) -> _ViewListOutputs
}

extension View {
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        .init()
    }

    public static func _makeViewList(
        view: _GraphValue<Self>,
        inputs: _ViewListInputs
    ) -> _ViewListOutputs {
        .init()
    }
}

extension Never: View {
    public var body: Never { fatalError() }
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        .init()
    }
}

public struct EmptyView: View {
    @inlinable public init() { }

    public var body: Never { fatalError() }
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        .init()
    }
}

public typealias EmptyContent = EmptyView

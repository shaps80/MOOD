import Swift

public protocol View {
    associatedtype Body: View
    var body: Body { get }

    @_documentation(visibility: internal)
    static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs
}

extension Never: View {
    public var body: Never { fatalError() }
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        .init()
    }
}

public struct EmptyView: View {
    public var body: Never { fatalError() }
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        .init()
    }
}

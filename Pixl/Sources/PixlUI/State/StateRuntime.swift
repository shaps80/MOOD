import Swift

struct _StateContext: @unchecked Sendable {
    let store: _StateStore
    let path: [UInt32]
    let viewType: ObjectIdentifier

    func location<Value>(field: String, initialValue: Value) -> _StateLocation<Value> {
        store.location(
            identity: .init(path: path, viewType: viewType, field: field),
            initialValue: initialValue
        )
    }
}

enum _StateRuntime {
    @TaskLocal static var context: _StateContext?
}

struct _ViewIdentity: Sendable {
    var path: [UInt32]

    static let root = Self(path: [0])

    func child(_ index: UInt32) -> Self {
        var path = path
        path.append(index)
        return .init(path: path)
    }
}

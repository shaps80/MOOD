import Swift

struct _StateIdentity: Hashable {
    let path: [_ViewIdentity.Component]
    let viewType: ObjectIdentifier
    let field: String
}

final class _StateStore: @unchecked Sendable {
    private var locations: [_StateIdentity: AnyObject] = [:]
    private(set) var generation: UInt64 = 0

    func location<Value>(
        identity: _StateIdentity,
        initialValue: Value
    ) -> _StateLocation<Value> {
        if let location = locations[identity] as? _StateLocation<Value> {
            return location
        }
        let location = _StateLocation(value: initialValue) { [weak self] in
            self?.generation &+= 1
        }
        locations[identity] = location
        return location
    }

    func invalidate() {
        generation &+= 1
    }
}

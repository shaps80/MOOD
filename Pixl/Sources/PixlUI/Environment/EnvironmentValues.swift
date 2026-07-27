import Swift

/// Values inherited by views while building and resolving a view graph.
public struct EnvironmentValues {
    private var storage: [ObjectIdentifier: Any] = [:]
    var containerShape: ViewGraph.NodeID = .invalid

    public init() { }

    public subscript<Key: EnvironmentKey>(_ key: Key.Type) -> Key.Value {
        get {
            storage[ObjectIdentifier(key)] as? Key.Value
                ?? Key.defaultValue
        }
        set {
            storage[ObjectIdentifier(key)] = newValue
        }
    }

    init(displayScale: Float) {
        self.displayScale = displayScale
    }
}

extension EnvironmentValues {
    /// Current number of presentation pixels per logical screen-space point.
    @Entry public internal(set) var displayScale: Float = 1
}

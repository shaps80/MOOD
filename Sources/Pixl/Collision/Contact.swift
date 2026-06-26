import Swift

public struct Contact: CustomStringConvertible, Sendable {
    public enum Phase: Sendable {
        case began
        case changed
        case ended
    }

    public struct Endpoint: Hashable, Sendable {
        public let id: EntityID
        public let collider: Int
    }

    struct Key: Hashable, Sendable {
        let source: Endpoint
        let target: Endpoint

        func hash(into hasher: inout Hasher) {
            hasher.combine(source)
            hasher.combine(target)
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.source == rhs.source
                && lhs.target == rhs.target
        }
    }

    public let source: Endpoint
    public let target: Endpoint
    public let phase: Phase

    var key: Key {
        Key(source: source, target: target)
    }

    public var description: String {
        "Contact(phase: \(phase), source: (\(source.id.rawValue), \(source.collider)), target: (\(target.id.rawValue), \(target.collider)))"
    }
}

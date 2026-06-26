import Swift

struct Contact: CustomStringConvertible, Sendable {
    enum Phase: Sendable {
        case began
        case changed
        case ended
    }

    struct Endpoint: Hashable, Sendable {
        let id: Entity.ID
        let collider: Int
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

    let source: Endpoint
    let target: Endpoint
    let phase: Phase

    var key: Key {
        Key(source: source, target: target)
    }

    var description: String {
        "Contact(phase: \(phase), source: (\(source.id.rawValue), \(source.collider)), target: (\(target.id.rawValue), \(target.collider)))"
    }
}

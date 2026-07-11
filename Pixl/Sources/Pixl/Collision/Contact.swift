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

    public struct TileEndpoint: Hashable, Sendable {
        public let column: Int
        public let row: Int
        public let collider: Int
    }

    public enum Target: Hashable, Sendable {
        case entity(Endpoint)
        case tile(TileEndpoint)

        public var id: EntityID? {
            guard case .entity(let endpoint) = self else {
                return nil
            }

            return endpoint.id
        }

        public var entity: Endpoint? {
            guard case .entity(let endpoint) = self else {
                return nil
            }

            return endpoint
        }

        public var tile: TileEndpoint? {
            guard case .tile(let endpoint) = self else {
                return nil
            }

            return endpoint
        }
    }

    struct Key: Hashable, Sendable {
        let source: Endpoint
        let target: Target

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
    public let target: Target
    public let phase: Phase

    var key: Key {
        Key(source: source, target: target)
    }

    public var description: String {
        let targetDescription: String

        switch target {
        case .entity(let endpoint):
            targetDescription = "entity(\(endpoint.id.rawValue), \(endpoint.collider))"
        case .tile(let endpoint):
            targetDescription = "tile(\(endpoint.column), \(endpoint.row), \(endpoint.collider))"
        }

        return "Contact(phase: \(phase), source: (\(source.id.rawValue), \(source.collider)), target: \(targetDescription))"
    }
}

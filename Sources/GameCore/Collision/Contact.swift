import Swift

struct Contact: CustomStringConvertible, Sendable {
    enum Phase: Sendable {
        case began
        case changed
        case ended
    }

    struct Key: Hashable, Sendable {
        let entity: (a: Entity.ID, b: Entity.ID)
        let collider: (a: Int, b: Int)

        init(entity: (a: Entity.ID, b: Entity.ID), collider: (a: Int, b: Int)) {
            if entity.a.rawValue < entity.b.rawValue
                || (entity.a.rawValue == entity.b.rawValue && collider.a <= collider.b) {
                self.entity = entity
                self.collider = collider
            } else {
                self.entity = (a: entity.b, b: entity.a)
                self.collider = (a: collider.b, b: collider.a)
            }
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(entity.a)
            hasher.combine(entity.b)
            hasher.combine(collider.a)
            hasher.combine(collider.b)
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.entity.a == rhs.entity.a
                && lhs.entity.b == rhs.entity.b
                && lhs.collider.a == rhs.collider.a
                && lhs.collider.b == rhs.collider.b
        }
    }

    let entity: (a: Entity.ID, b: Entity.ID)
    let collider: (a: Int, b: Int)
    let phase: Phase

    var key: Key {
        Key(entity: entity, collider: collider)
    }

    var description: String {
        "Contact(phase: \(phase), entity: (\(entity.a.rawValue), \(entity.b.rawValue)), collider: (\(collider.a), \(collider.b)))"
    }
}

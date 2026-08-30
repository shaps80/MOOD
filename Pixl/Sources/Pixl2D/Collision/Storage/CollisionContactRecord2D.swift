struct CollisionContactRecord2D: Comparable {
    let source: CollisionEndpoint2D
    let target: CollisionEndpoint2D
    let contact: Contact2D

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.key == rhs.key
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.key < rhs.key
    }

    func hasSameKey(as other: Self) -> Bool {
        key == other.key
    }

    private var key: (Int32, UInt32, Int32, UInt32) {
        (
            source.collider.index,
            source.collider.generation,
            target.collider.index,
            target.collider.generation
        )
    }
}

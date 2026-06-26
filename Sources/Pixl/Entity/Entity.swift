import Swift

public protocol Entity {
    init()

    var size: Vec2 { get }
    var colliders: [Collider] { get }

    mutating func onUpdate(
        context: inout Game.Context,
        state: inout EntityState
    )

    mutating func onCollision(
        context: inout Game.Context,
        state: inout EntityState,
        contact: Contact
    )

    func sprite(
        for state: EntityState
    ) -> Sprite?
}

public extension Entity {
    var colliders: [Collider] { [] }
    
    mutating func onCollision(
        context: inout Game.Context,
        state: inout EntityState,
        contact: Contact
    ) { }
}

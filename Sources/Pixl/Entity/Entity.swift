import Swift

public protocol Entity: SendableMetatype {
    init()

    static var kind: EntityKind { get }

    mutating func prepare(
        context: inout Game.PreparationContext,
        state: inout EntityState
    )

    mutating func onUpdate(
        context: inout Game.Context,
        state: inout EntityState
    )

    mutating func onCollision(
        context: inout Game.Context,
        state: inout EntityState,
        contact: Contact
    )
}

public extension Entity {
    static var kind: EntityKind {
        .init(rawValue: String(describing: self))
    }
}

public extension Entity {
    mutating func prepare(
        context: inout Game.PreparationContext,
        state: inout EntityState
    ) { }
    
    mutating func onCollision(
        context: inout Game.Context,
        state: inout EntityState,
        contact: Contact
    ) { }
}

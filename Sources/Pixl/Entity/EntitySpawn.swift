import Swift

public struct EntitySpawn {
    public let id: EntityID
    public var entity: any Entity
    public var position: Vec2

    public init(id: EntityID, entity: any Entity, position: Vec2) {
        self.id = id
        self.entity = entity
        self.position = position
    }
}

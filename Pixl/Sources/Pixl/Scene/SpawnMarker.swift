import Swift

public struct SpawnMarker {
    public let kind: EntityKind
    public let position: Vec2

    public init(kind: EntityKind, position: Vec2) {
        self.kind = kind
        self.position = position
    }
}

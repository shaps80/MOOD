import Swift

public struct Level: Equatable, Sendable {
    public let tilemap: Tilemap
    public let spawnPoint: Vec2

    public init(tilemap: Tilemap, spawnPoint: Vec2) {
        self.tilemap = tilemap
        self.spawnPoint = spawnPoint
    }

    public var bounds: Rect {
        tilemap.bounds
    }
}

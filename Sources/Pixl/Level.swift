import Swift

public struct Level: Equatable, Sendable {
    public let tilemap: Tilemap
    public let spawnPoint: Vec2

    public init(tilemap: Tilemap, spawnPoint: Vec2) {
        self.tilemap = tilemap
        self.spawnPoint = spawnPoint
    }

    public init(tilemap: Tilemap, spawnColumn: Int, spawnRow: Int) {
        self.init(
            tilemap: tilemap,
            spawnPoint: Vec2(
                x: (Double(spawnColumn) + 0.5) * tilemap.tileSize.x,
                y: (Double(spawnRow) + 0.5) * tilemap.tileSize.y
            )
        )
    }

    public var bounds: Rect {
        tilemap.bounds
    }
}

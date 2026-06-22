import Swift

public struct Tilemap: Sendable {
    public let size: Vec2
    public let tileSize: Vec2
    public let tiles: [Tile]

    public init(size: Vec2, tileSize: Vec2, tiles: [Tile]) {
        self.size = size
        self.tileSize = tileSize
        self.tiles = tiles
    }
}

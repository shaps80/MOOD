import Swift

extension Tilemap.Tile {
    public enum Kind: Sendable {
        case floor
        case wall
        case empty
    }
}

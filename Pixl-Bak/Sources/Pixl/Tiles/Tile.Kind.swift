import Swift

extension Tilemap.Tile {
    public enum Kind: Equatable, Sendable {
        case floor
        case wall
        case empty
    }
}

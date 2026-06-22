import Swift

extension Tilemap {
    public struct Tile: Equatable, Sendable {
        public let kind: Kind
        public let material: Material

        public init(kind: Kind, material: Material) {
            self.kind = kind
            self.material = material
        }
    }
}

extension Tilemap.Tile {
    public static let empty: Self = .init(
        kind: .empty,
        material: .color(
            .clear
        )
    )
}

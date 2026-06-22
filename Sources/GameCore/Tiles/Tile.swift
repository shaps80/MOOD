import Swift

extension Tilemap {
    public struct Tile: Equatable, Sendable {
        public let kind: Kind
        public let material: Material
        /// Optional local-space collider relative to this tile's origin.
        public let collider: Collider?

        public init(kind: Kind, material: Material, collider: Collider? = nil) {
            self.kind = kind
            self.material = material
            self.collider = collider
        }
    }
}

extension Tilemap.Tile {
    public static let empty: Self = .init(
        kind: .empty,
        material: .color(.clear)
    )
}

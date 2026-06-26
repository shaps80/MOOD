import Swift

extension Tilemap {
    public struct Tile: Equatable, Sendable {
        public let kind: Kind
        public let material: Material
        public let layer: Layer
        /// Optional local-space collider relative to this tile's origin.
        public let collider: Collider?

        public init(
            kind: Kind,
            material: Material,
            layer: Layer = .world,
            collider: Collider? = nil
        ) {
            self.kind = kind
            self.material = material
            self.layer = layer
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

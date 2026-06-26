import Swift

extension Tilemap {
    public struct Tile: Equatable, Sendable {
        public let kind: Kind
        public let material: Material
        public let layer: RenderLayer
        /// Optional local-space collider relative to this tile's origin.
        public let collider: Collider?

        public init(
            kind: Kind,
            material: Material,
            layer: RenderLayer = .world,
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

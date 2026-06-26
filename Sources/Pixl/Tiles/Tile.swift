import Swift

extension Tilemap {
    public struct Tile: Equatable, Sendable {
        public let kind: Kind
        public let material: Material
        public let layer: RenderLayer
        /// Local-space colliders relative to this tile's origin.
        public let colliders: [Collider]

        public init(
            kind: Kind,
            material: Material,
            layer: RenderLayer = .world,
            collider: Collider? = nil
        ) {
            self.init(
                kind: kind,
                material: material,
                layer: layer,
                colliders: collider.map { [$0] } ?? []
            )
        }

        public init(
            kind: Kind,
            material: Material,
            layer: RenderLayer = .world,
            colliders: [Collider]
        ) {
            self.kind = kind
            self.material = material
            self.layer = layer
            self.colliders = colliders
        }
    }
}

extension Tilemap.Tile {
    public static let empty: Self = .init(
        kind: .empty,
        material: .color(.clear)
    )
}

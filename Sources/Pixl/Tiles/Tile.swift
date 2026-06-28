import Swift

extension Tilemap {
    public struct Tile: Equatable, Sendable {
        public let kind: Kind
        public let material: Material
        public let layer: RenderLayer
        public let tint: Color
        /// Local-space colliders relative to this tile's origin.
        public let colliders: [Collider]

        public init(
            kind: Kind,
            material: Material,
            layer: RenderLayer = 0,
            tint: Color = .white,
            collider: Collider? = nil
        ) {
            self.init(
                kind: kind,
                material: material,
                layer: layer,
                tint: tint,
                colliders: collider.map { [$0] } ?? []
            )
        }

        public init(
            kind: Kind,
            material: Material,
            layer: RenderLayer = 0,
            tint: Color = .white,
            colliders: [Collider]
        ) {
            self.kind = kind
            self.material = material
            self.layer = layer
            self.tint = tint
            self.colliders = colliders
        }
    }
}

extension Tilemap.Tile {
    public static let empty: Self = .init(
        kind: .empty,
        material: .shape(Rectangle()),
        tint: .clear
    )
}

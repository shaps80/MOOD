import Swift

extension Tilemap {
    public struct Tile: Sendable {
        public let kind: Kind
        public let material: Material

        public init(kind: Kind, material: Material) {
            self.kind = kind
            self.material = material
        }
    }
}

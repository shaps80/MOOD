extension Font {
    package struct GlyphDebugInfo: Hashable, Sendable {
        package struct Bounds: Hashable, Sendable {
            package let x: Float
            package let y: Float
            package let width: Float
            package let height: Float
        }

        package let scalar: Unicode.Scalar
        package let glyphID: UInt16
        package let cluster: GlyphCluster
        package let advance: Float
        package let typographicBounds: Bounds
        package let renderBounds: Bounds?
    }
}

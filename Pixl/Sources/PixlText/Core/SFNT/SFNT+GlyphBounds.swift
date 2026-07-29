extension SFNT {
    struct GlyphBounds: Hashable, Sendable {
        let xMin: Int16
        let yMin: Int16
        let xMax: Int16
        let yMax: Int16
    }
}

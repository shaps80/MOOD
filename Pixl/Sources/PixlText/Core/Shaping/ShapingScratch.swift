struct ShapingScratch: ~Copyable {
    static let renderBoundsCapacity = 64

    var glyphs: GlyphBuffer
    var scratch: GlyphBuffer
    var renderBoundsGlyphs: [GlyphID]
    var renderBoundsValues: [SFNT.GlyphBounds?]

    init(minimumGlyphCapacity: Int) {
        glyphs = .init(minimumCapacity: minimumGlyphCapacity)
        scratch = .init(minimumCapacity: minimumGlyphCapacity)
        renderBoundsGlyphs = []
        renderBoundsGlyphs.reserveCapacity(min(minimumGlyphCapacity, Self.renderBoundsCapacity))
        renderBoundsValues = []
        renderBoundsValues.reserveCapacity(min(minimumGlyphCapacity, Self.renderBoundsCapacity))
    }

    mutating func swapBuffers() {
        swap(&glyphs, &scratch)
    }

    mutating func removeRenderBoundsCache() {
        renderBoundsGlyphs.removeAll(keepingCapacity: true)
        renderBoundsValues.removeAll(keepingCapacity: true)
    }
}

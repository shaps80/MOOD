struct ShapingWorkspace: ~Copyable {
    var glyphs: GlyphBuffer
    var scratch: GlyphBuffer

    init(minimumGlyphCapacity: Int) {
        glyphs = .init(minimumCapacity: minimumGlyphCapacity)
        scratch = .init(minimumCapacity: minimumGlyphCapacity)
    }
}

struct ShapingScratch: ~Copyable {
    var glyphs: GlyphBuffer
    var scratch: GlyphBuffer

    init(minimumGlyphCapacity: Int) {
        glyphs = .init(minimumCapacity: minimumGlyphCapacity)
        scratch = .init(minimumCapacity: minimumGlyphCapacity)
    }

    mutating func swapBuffers() {
        swap(&glyphs, &scratch)
    }
}

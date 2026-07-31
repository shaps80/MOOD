struct ShapingWorkspace: ~Copyable {
    var scratch: ShapingScratch
    var glyphs: GlyphBuffer
    var runs: GlyphRunBuffer
    var normalization: UnicodeNormalizationBuffer

    init(minimumGlyphCapacity: Int, minimumRunCapacity: Int) {
        scratch = .init(minimumGlyphCapacity: minimumGlyphCapacity)
        glyphs = .init(minimumCapacity: minimumGlyphCapacity)
        runs = .init(minimumCapacity: minimumRunCapacity)
        normalization = .init()
    }

    mutating func removeAll(keepingCapacity: Bool = true) {
        scratch.glyphs.removeAll(keepingCapacity: keepingCapacity)
        scratch.scratch.removeAll(keepingCapacity: keepingCapacity)
        glyphs.removeAll(keepingCapacity: keepingCapacity)
        runs.removeAll(keepingCapacity: keepingCapacity)
        normalization.removeAll(keepingCapacity: keepingCapacity)
    }
}

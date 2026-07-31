struct ShapingWorkspace: ~Copyable {
    var inputRuns: TextRunBuffer
    var scratch: ShapingScratch
    var glyphs: GlyphBuffer
    var insertionGlyphs: GlyphBuffer
    var runs: GlyphRunBuffer
    var normalization: UnicodeNormalizationBuffer

    init(minimumGlyphCapacity: Int, minimumRunCapacity: Int) {
        inputRuns = .init(minimumCapacity: minimumRunCapacity)
        scratch = .init(minimumGlyphCapacity: minimumGlyphCapacity)
        glyphs = .init(minimumCapacity: minimumGlyphCapacity)
        insertionGlyphs = .init(minimumCapacity: minimumRunCapacity * 2)
        runs = .init(minimumCapacity: minimumRunCapacity)
        normalization = .init()
    }

    mutating func removeAll(keepingCapacity: Bool = true) {
        inputRuns.removeAll(keepingCapacity: keepingCapacity)
        removeOutput(keepingCapacity: keepingCapacity)
    }

    mutating func removeOutput(keepingCapacity: Bool = true) {
        scratch.glyphs.removeAll(keepingCapacity: keepingCapacity)
        scratch.scratch.removeAll(keepingCapacity: keepingCapacity)
        glyphs.removeAll(keepingCapacity: keepingCapacity)
        insertionGlyphs.removeAll(keepingCapacity: keepingCapacity)
        runs.removeAll(keepingCapacity: keepingCapacity)
        normalization.removeAll(keepingCapacity: keepingCapacity)
    }
}

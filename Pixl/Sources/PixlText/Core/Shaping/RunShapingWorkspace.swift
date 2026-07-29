struct RunShapingWorkspace: ~Copyable {
    var run: ShapingWorkspace
    var glyphs: GlyphBuffer
    var runs: GlyphRunBuffer
    var normalization: UnicodeNormalizationBuffer

    init(minimumGlyphCapacity: Int, minimumRunCapacity: Int) {
        run = .init(minimumGlyphCapacity: minimumGlyphCapacity)
        glyphs = .init(minimumCapacity: minimumGlyphCapacity)
        runs = .init(minimumCapacity: minimumRunCapacity)
        normalization = .init()
    }

    mutating func removeAll(keepingCapacity: Bool = true) {
        run.glyphs.removeAll(keepingCapacity: keepingCapacity)
        run.scratch.removeAll(keepingCapacity: keepingCapacity)
        glyphs.removeAll(keepingCapacity: keepingCapacity)
        runs.removeAll(keepingCapacity: keepingCapacity)
        normalization.removeAll(keepingCapacity: keepingCapacity)
    }
}

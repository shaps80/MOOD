struct LineLayoutWorkspace: ~Copyable {
    var positions: PositionedGlyphBuffer
    var insertions: PositionedInsertionBuffer
    var lines: PositionedLineBuffer
    var paragraphs: PositionedParagraphBuffer

    init(
        minimumGlyphCapacity: Int = 0,
        minimumLineCapacity: Int = 0,
        minimumParagraphCapacity: Int = 0
    ) {
        positions = .init(minimumCapacity: minimumGlyphCapacity)
        insertions = .init(minimumCapacity: minimumLineCapacity)
        lines = .init(minimumCapacity: minimumLineCapacity)
        paragraphs = .init(minimumCapacity: minimumParagraphCapacity)
    }

    mutating func removeAll(keepingCapacity: Bool = true) {
        positions.removeAll(keepingCapacity: keepingCapacity)
        insertions.removeAll(keepingCapacity: keepingCapacity)
        lines.removeAll(keepingCapacity: keepingCapacity)
        paragraphs.removeAll(keepingCapacity: keepingCapacity)
    }
}

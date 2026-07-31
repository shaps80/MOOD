struct LineLayoutWorkspace: ~Copyable {
    var positions: PositionedGlyphBuffer
    var lines: PositionedLineBuffer

    init(minimumGlyphCapacity: Int = 0, minimumLineCapacity: Int = 0) {
        positions = .init(minimumCapacity: minimumGlyphCapacity)
        lines = .init(minimumCapacity: minimumLineCapacity)
    }

    mutating func removeAll(keepingCapacity: Bool = true) {
        positions.removeAll(keepingCapacity: keepingCapacity)
        lines.removeAll(keepingCapacity: keepingCapacity)
    }
}

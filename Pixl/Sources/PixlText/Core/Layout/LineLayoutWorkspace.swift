struct LineLayoutWorkspace: ~Copyable {
    var positions: PositionedGlyphBuffer

    init(minimumGlyphCapacity: Int = 0) {
        positions = .init(minimumCapacity: minimumGlyphCapacity)
    }

    mutating func removeAll(keepingCapacity: Bool = true) {
        positions.removeAll(keepingCapacity: keepingCapacity)
    }
}

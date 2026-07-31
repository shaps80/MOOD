struct PositionedInsertion: Hashable, Sendable {
    let kind: InsertionKind
    let glyphID: GlyphID
    let face: SFNT.Face
    let size: Float
    let sourceOffset: Int
    let position: PositionedGlyph
    let advance: Float
    let renderBounds: PositionedLine.Bounds?
}

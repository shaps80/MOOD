struct ShapedInsertionToken: Hashable, Sendable {
    let kind: InsertionKind
    let glyphRange: Range<Int>
    let face: SFNT.Face
    let size: Float
}

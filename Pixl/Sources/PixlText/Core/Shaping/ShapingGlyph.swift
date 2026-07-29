struct ShapingGlyph {
    var id: GlyphID
    var sourceRange: Range<Int>
    var lookupIndex: Int?
    var feature: UInt32?
    var xPlacement: Int32 = 0
    var yPlacement: Int32 = 0
    var xAdvance: Int32 = 0
    var yAdvance: Int32 = 0
}

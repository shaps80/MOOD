struct ShapingGlyph {
    var id: GlyphID
    var sourceRange: Range<Int>
    var lookupIndex: Int?
    var feature: UInt32?
    var nominalXAdvance: Int32 = 0
    var nominalYAdvance: Int32 = 0
    var ligatureComponentCount: UInt16 = 0
    var ligatureComponent: UInt16 = 0
    var xPlacement: Int32 = 0
    var yPlacement: Int32 = 0
    var xAdvance: Int32 = 0
    var yAdvance: Int32 = 0
    var renderBounds: SFNT.GlyphBounds?
}

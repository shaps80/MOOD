struct GlyphRun: Hashable, Sendable {
    let sourceRange: Range<Int>
    let glyphRange: Range<Int>
    let face: SFNT.Face
    let size: Float
    let direction: TextDirection
    let script: UnicodeScript
    let language: UInt32?
}

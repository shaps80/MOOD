struct PositionedLine: Hashable, Sendable {
    struct Bounds: Hashable, Sendable {
        let x: Float
        let y: Float
        let width: Float
        let height: Float
    }

    let positionRange: Range<Int>
    let consumedSourceRange: Range<Int>
    let consumedGlyphRange: Range<Int>
    let visibleGlyphRange: Range<Int>
    let breakKind: LineBreakKind
    let advance: Float
    let ascent: Float
    let descent: Float
    let leading: Float
    let naturalAbove: Float
    let naturalBelow: Float
    let baselineY: Float
    let baselineOffset: Float
    let typographicBounds: Bounds
    let lineBounds: Bounds
    let renderBounds: Bounds?
}

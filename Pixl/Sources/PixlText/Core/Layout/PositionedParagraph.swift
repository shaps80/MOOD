struct PositionedParagraph: Hashable, Sendable {
    let lineRange: Range<Int>
    let consumedSourceRange: Range<Int>
    let bounds: PositionedLine.Bounds
    let renderBounds: PositionedLine.Bounds?
    let firstBaselineY: Float
    let lastBaselineY: Float
}

struct LineComposition: Hashable, Sendable {
    let line: PositionedLine
    let next: LineStart?
}

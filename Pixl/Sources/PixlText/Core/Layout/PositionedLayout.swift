struct PositionedLayout: Hashable, Sendable {
    let status: LayoutStatus
    let bounds: PositionedLine.Bounds
    let reservedLineCount: UInt
}

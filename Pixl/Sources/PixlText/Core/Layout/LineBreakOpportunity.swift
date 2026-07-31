struct LineBreakOpportunity: Hashable, Sendable {
    let sourceOffset: Int
    let kind: LineBreakKind
}

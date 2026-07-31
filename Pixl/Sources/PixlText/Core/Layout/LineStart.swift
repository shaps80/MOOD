struct LineStart: Hashable, Sendable {
    let sourceOffset: Int
    let glyphIndex: Int
    let runIndex: Int
    let opportunityIndex: Int
    let unitIndex: Int
}

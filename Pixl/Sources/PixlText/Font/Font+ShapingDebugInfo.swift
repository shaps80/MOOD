extension Font {
    package struct ShapingDebugInfo: Hashable, Sendable {
        package let source: String
        package let sourceRange: Range<Int>
        package let normalizedScalars: [Unicode.Scalar]
        package let nominalGlyphIDs: [UInt16]
        package let shapedGlyphIDs: [UInt16]
        package let feature: String?
        package let lookupIndex: Int?
    }
}

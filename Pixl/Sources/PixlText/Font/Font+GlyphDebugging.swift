extension Font {
    package func forEachGlyph(
        in text: String,
        _ body: (GlyphDebugInfo) -> Void
    ) throws {
        try Registry.shared.forEachGlyph(
            in: text,
            descriptor: descriptor,
            body
        )
    }
}

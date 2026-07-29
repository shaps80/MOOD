extension Font {
    package func forEachGlyph(
        in text: String,
        fontBytes: [UInt8]? = nil,
        fontID: String? = nil,
        _ body: (GlyphDebugInfo) -> Void
    ) throws {
        try Registry.shared.forEachGlyph(
            in: text,
            descriptor: descriptor,
            fontBytes: fontBytes,
            fontID: fontID,
            body
        )
    }

    package static func registerSystemFont(bytes: [UInt8]) throws {
        try Registry.shared.registerSystemFont(bytes: bytes)
    }
}

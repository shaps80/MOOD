extension Font {
    package func shapingDebugInfo(
        in text: String,
        fontPath: String
    ) throws -> [ShapingDebugInfo] {
        try Registry.shared.shapingDebugInfo(in: text, fontPath: fontPath)
    }
}

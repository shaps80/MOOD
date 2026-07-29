extension Font {
    package func shapingDebugInfo(
        in text: String,
        fontBytes: [UInt8],
        fontID: String
    ) throws -> [ShapingDebugInfo] {
        try Registry.shared.shapingDebugInfo(
            in: text,
            fontBytes: fontBytes,
            fontID: fontID
        )
    }
}

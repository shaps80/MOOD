extension Font {
    package static func runDebugInfo(
        in text: String,
        runs: [RunDebugInfo.Input],
        maximumLineWidth: Float,
        lineHeight: RunDebugInfo.LineHeight
    ) throws -> RunDebugInfo {
        try Registry.shared.runDebugInfo(
            in: text,
            inputs: runs,
            maximumLineWidth: maximumLineWidth,
            lineHeight: lineHeight
        )
    }
}

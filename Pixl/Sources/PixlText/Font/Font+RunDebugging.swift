extension Font {
    package static func runDebugInfo(
        in text: String,
        runs: [RunDebugInfo.Input],
        constraints: LayoutConstraints,
        lineHeight: RunDebugInfo.LineHeight,
        paragraphStyles: [ParagraphStyle]
    ) throws -> RunDebugInfo {
        try Registry.shared.runDebugInfo(
            in: text,
            inputs: runs,
            constraints: constraints,
            lineHeight: lineHeight,
            paragraphStyles: paragraphStyles
        )
    }
}

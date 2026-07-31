extension Font {
    package static func runDebugInfo(
        in text: String,
        font: RunDebugInfo.FontInput,
        overrides: [RunDebugInfo.Input] = [],
        constraints: LayoutConstraints,
        lineHeight: RunDebugInfo.LineHeight,
        paragraphStyles: [ParagraphStyle]
    ) throws -> RunDebugInfo {
        try Registry.shared.runDebugInfo(
            in: text,
            font: font,
            overrides: overrides,
            constraints: constraints,
            lineHeight: lineHeight,
            paragraphStyles: paragraphStyles
        )
    }
}

package struct ParagraphStyle: Hashable, Sendable {
    package var alignment: TextAlignment
    package var indentation: Indentation
    package var spacing: Spacing
    package var hyphenation: Hyphenation

    package init(
        alignment: TextAlignment = .leading,
        indentation: Indentation = .init(),
        spacing: Spacing = .init(),
        hyphenation: Hyphenation = .automatic
    ) {
        self.alignment = alignment
        self.indentation = indentation
        self.spacing = spacing
        self.hyphenation = hyphenation
    }

    var isValid: Bool {
        indentation.isValid && spacing.isValid
    }
}

package struct LayoutConstraints: Hashable, Sendable {
    package var width: Float
    package var lines: LineLimit
    package var overflow: Overflow

    package init(
        width: Float,
        lines: LineLimit = .init(),
        overflow: Overflow = .visible
    ) {
        self.width = width
        self.lines = lines
        self.overflow = overflow
    }

    var isValid: Bool {
        width >= 0 && width.isFinite && lines.isValid
    }
}

package struct LayoutConstraints: Hashable, Sendable {
    package var width: Float
    package var lines: LineLimit
    package var overflow: Overflow
    package var defaultLineMetrics: DefaultLineMetrics

    package init(
        width: Float,
        lines: LineLimit = .init(),
        overflow: Overflow = .visible,
        defaultLineMetrics: DefaultLineMetrics = .automatic
    ) {
        self.width = width
        self.lines = lines
        self.overflow = overflow
        self.defaultLineMetrics = defaultLineMetrics
    }

    var isValid: Bool {
        width >= 0 && width.isFinite && lines.isValid
    }
}

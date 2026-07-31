package struct Indentation: Hashable, Sendable {
    package var leading: Float
    package var trailing: Float
    package var firstLine: Float

    package init(
        leading: Float = 0,
        trailing: Float = 0,
        firstLine: Float = 0
    ) {
        self.leading = leading
        self.trailing = trailing
        self.firstLine = firstLine
    }

    var isValid: Bool {
        leading >= 0 && leading.isFinite
            && trailing >= 0 && trailing.isFinite
            && firstLine >= 0 && firstLine.isFinite
    }
}

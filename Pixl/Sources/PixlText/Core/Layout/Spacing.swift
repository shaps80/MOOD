package struct Spacing: Hashable, Sendable {
    package var lineSpacing: Float
    package var paragraphBefore: Float
    package var paragraphAfter: Float

    package init(
        lineSpacing: Float = 0,
        paragraphBefore: Float = 0,
        paragraphAfter: Float = 0
    ) {
        self.lineSpacing = lineSpacing
        self.paragraphBefore = paragraphBefore
        self.paragraphAfter = paragraphAfter
    }

    var isValid: Bool {
        lineSpacing >= 0 && lineSpacing.isFinite
            && paragraphBefore >= 0 && paragraphBefore.isFinite
            && paragraphAfter >= 0 && paragraphAfter.isFinite
    }
}

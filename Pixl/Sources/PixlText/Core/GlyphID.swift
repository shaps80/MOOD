public struct GlyphID: Hashable, Sendable {
    public let rawValue: UInt16

    init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
}

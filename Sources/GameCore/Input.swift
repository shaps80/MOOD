import Swift

public struct InputState: Equatable, Sendable {
    public let horizontal: Double
    public let vertical: Double
    public let jump: Bool

    public init(horizontal: Double = 0, vertical: Double = 0, jump: Bool = false) {
        self.horizontal = horizontal
        self.vertical = vertical
        self.jump = jump
    }
}

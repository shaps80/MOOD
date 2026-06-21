import Swift

public struct Input: Equatable, Sendable {
    public let horizontal: Double
    public let vertical: Double
    public let jump: Bool

    public init(horizontal: Double = 0, vertical: Double = 0, jump: Bool = false) {
        self.horizontal = horizontal
        self.vertical = vertical
        self.jump = jump
    }

    public func combined(with other: Input) -> Input {
        Input(
            horizontal: clamp(horizontal + other.horizontal, min: -1, max: 1),
            vertical: clamp(vertical + other.vertical, min: -1, max: 1),
            jump: jump || other.jump
        )
    }
}

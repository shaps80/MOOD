import Swift

public struct PositionPair: BitwiseCopyable, Sendable {
    public let previous: Position
    public let current: Position

    public init(previous: Position, current: Position) {
        self.previous = previous
        self.current = current
    }
}

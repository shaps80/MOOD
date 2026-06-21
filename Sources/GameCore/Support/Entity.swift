import Swift

public struct Entity: Equatable, Sendable {
    internal var size: Vec2
    internal var position: Vec2
    internal var velocity: Vec2

    public init(position: Vec2, size: Vec2) {
        self.position = position
        self.size = size
        self.velocity = .zero
    }

    mutating func move(to position: Vec2, velocity: Vec2) {
        self.position = position
        self.velocity = velocity
    }
}

import Swift

public struct Particle: Identifiable {
    public typealias ID = UInt64

    public let id: ID
    public internal(set) var position: Vec3

    var previousPosition: Vec3
    let velocity: Vec3

    init(
        id: ID,
        position: Vec3,
        velocity: Vec3
    ) {
        self.id = id
        self.previousPosition = position
        self.position = position
        self.velocity = velocity
    }

    init(
        id: ID,
        previousPosition: Vec3,
        position: Vec3,
        velocity: Vec3
    ) {
        self.id = id
        self.previousPosition = previousPosition
        self.position = position
        self.velocity = velocity
    }

    public func interpolated(by fraction: Float) -> Vec3 {
        previousPosition + (position - previousPosition) * fraction
    }

    mutating func advance(by delta: Float) {
        previousPosition = position
        position += velocity * delta
    }

    mutating func resetInterpolation() {
        previousPosition = position
    }
}

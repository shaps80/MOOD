import Swift

public struct Particle: Identifiable {
    public typealias ID = UInt64

    public let id: ID
    public internal(set) var position: Vec3
    public internal(set) var color: Color

    var previousPosition: Vec3
    var previousColor: Color
    let velocity: Vec3

    init(
        id: ID,
        position: Vec3,
        velocity: Vec3,
        color: Color
    ) {
        self.id = id
        self.previousPosition = position
        self.position = position
        self.previousColor = color
        self.color = color
        self.velocity = velocity
    }

    init(
        id: ID,
        previousPosition: Vec3,
        position: Vec3,
        velocity: Vec3,
        previousColor: Color,
        color: Color
    ) {
        self.id = id
        self.previousPosition = previousPosition
        self.position = position
        self.previousColor = previousColor
        self.color = color
        self.velocity = velocity
    }

    public func interpolated(by fraction: Float) -> Vec3 {
        previousPosition + (position - previousPosition) * fraction
    }

    mutating func advance(by delta: Float) {
        previousPosition = position
        previousColor = color
        position += velocity * delta
    }

    mutating func resetInterpolation() {
        previousPosition = position
        previousColor = color
    }
}

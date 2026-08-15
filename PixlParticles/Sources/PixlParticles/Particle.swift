import Swift

public struct Particle {
    public internal(set) var position: Vec3

    var previousPosition: Vec3
    let velocity: Vec3

    init(
        position: Vec3,
        velocity: Vec3
    ) {
        previousPosition = position
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
}

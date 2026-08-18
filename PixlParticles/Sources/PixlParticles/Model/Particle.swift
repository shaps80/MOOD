import Swift

public struct Particle: Identifiable {
    public typealias ID = UInt64

    public let id: ID
    public internal(set) var position: Vec3
    public internal(set) var color: Color

    var previousPosition: Vec3
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
        self.color = color
        self.velocity = velocity
    }

    init(
        id: ID,
        previousPosition: Vec3,
        position: Vec3,
        velocity: Vec3,
        color: Color
    ) {
        self.id = id
        self.previousPosition = previousPosition
        self.position = position
        self.color = color
        self.velocity = velocity
    }

    public func interpolated(by fraction: Float) -> Vec3 {
        previousPosition + (position - previousPosition) * fraction
    }

}

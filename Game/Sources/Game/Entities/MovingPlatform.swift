import Pixl2D

struct MovingPlatform {
    private(set) var bounds: Rect

    private let minimumY: Float
    private let maximumY: Float
    private let speed: Float
    private let collider: ColliderID
    private var direction: Float

    init(
        bounds: Rect,
        verticalTravel: Float,
        speed: Float,
        startsMovingUp: Bool,
        collisions: CollisionWorld2D
    ) {
        var initialBounds = bounds
        if !startsMovingUp {
            initialBounds.origin.y += verticalTravel
        }
        self.bounds = initialBounds
        minimumY = bounds.minY
        maximumY = bounds.minY + verticalTravel
        self.speed = speed
        direction = startsMovingUp ? 1 : -1
        collider = collisions.insert(
            bounds: initialBounds,
            mode: .dynamic,
            layer: .world,
            mask: .none
        )
    }

    mutating func fixedUpdate(
        delta: Float,
        collisions: CollisionWorld2D
    ) {
        var nextY = bounds.origin.y + (speed * delta * direction)

        if nextY >= maximumY {
            nextY = maximumY - (nextY - maximumY)
            direction = -1
        } else if nextY <= minimumY {
            nextY = minimumY + (minimumY - nextY)
            direction = 1
        }

        bounds.origin.y = nextY
        collisions.update(collider, bounds: bounds)
    }
}

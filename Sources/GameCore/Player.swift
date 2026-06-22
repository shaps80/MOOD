import Swift

struct Player {
    private let size: Vec2 = .init(x: 64, y: 64)
    private var wasJumpPressed = false

    private var entity: Entity
    private var speed: Double = 400
    private var acceleration: Double = 1200
    private var deceleration: Double = 1000
    private var walkTimeline: SpriteAnimation.Timeline


    static let `default` = Player()

    private init() {
        self.entity = .init(
            position: .zero,
            size: size
        )
        self.walkTimeline = .init(animation: Self.walk)
    }

    var sprite: Sprite {
        let animation = walkTimeline.animation

        return Sprite(
            position: entity.position,
            size: entity.size,
            material: .sprite(
                animation.textureID,
                sourceRect: walkTimeline.frame
            )
        )
    }

    public mutating func place(in worldSize: Vec2) {
        entity.position = .init(
            x: (worldSize.x - size.x) / 2,
            y: (worldSize.y - size.y) / 2
        )
    }

    public mutating func update(delta: Double, context: inout Game.Context) {
        let input = context.input
        let worldSize = context.worldSize

        walkTimeline.update(delta: delta)

        defer {
            wasJumpPressed = input.jump
        }

        let step = max(delta, 0)
        let leftBound = 0.0
        let rightBound = worldSize.x - entity.size.x
        let topBound = 0.0
        let bottomBound = worldSize.y - entity.size.y

        var velocity = Vec2(
            x: velocity(
                current: entity.velocity.x,
                input: input.horizontal,
                delta: step
            ),
            y: velocity(
                current: entity.velocity.y,
                input: input.vertical,
                delta: step
            )
        )

        let proposedX = entity.position.x + (velocity.x * step)
        let proposedY = entity.position.y + (velocity.y * step)
        let nextX = clamp(
            proposedX,
            min: leftBound,
            max: rightBound
        )

        let nextY = clamp(
            proposedY,
            min: topBound,
            max: bottomBound
        )

        if nextX != proposedX {
            velocity = Vec2(x: 0, y: velocity.y)
        }

        if nextY != proposedY {
            velocity = Vec2(x: velocity.x, y: 0)
        }

        entity.move(
            to: Vec2(x: nextX, y: nextY),
            velocity: velocity
        )

        if input.jump && !wasJumpPressed {
            context.play(sound: .jump)
        }
    }

    private func velocity(current: Double, input: Double, delta: Double) -> Double {
        guard input != 0 else {
            return decelerate(current, delta: delta)
        }

        let target = input * speed
        if isReversing(current: current, target: target) {
            return decelerate(current, delta: delta)
        }

        return accelerate(current, toward: target, delta: delta)
    }

    private func accelerate(_ current: Double, toward target: Double, delta: Double) -> Double {
        let step = acceleration * delta

        if current < target {
            return min(current + step, target)
        }

        return max(current - step, target)
    }

    private func decelerate(_ current: Double, delta: Double) -> Double {
        let step = deceleration * delta

        if abs(current) <= step {
            return 0
        }

        return current > 0 ? current - step : current + step
    }

    private func isReversing(current: Double, target: Double) -> Bool {
        (current < 0 && target > 0) || (current > 0 && target < 0)
    }
}

extension Player {
    private static let walk = SpriteAnimation(
        textureID: .player,
        frames: [
            Rect(x: 0, y: 0, width: 48, height: 48),
            Rect(x: 48, y: 0, width: 48, height: 48),
            Rect(x: 96, y: 0, width: 48, height: 48),
            Rect(x: 144, y: 0, width: 48, height: 48)
        ],
        frameDuration: 0.12
    )
}

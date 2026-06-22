import Swift

struct Player {
    private let size: Vec2 = .init(x: 32, y: 32)
    private var timeline: SpriteAnimation.Timeline = .init(animation: .walk)
    private var wasJumpPressed = false

    private var entity: Entity
    private var speed: Double = 200
    private var acceleration: Double = 1200
    private var deceleration: Double = 1000


    static let `default` = Player()

    private init() {
        self.entity = .init(
            position: .zero,
            size: size,
            collider: Collider(
                bounds: Rect(
                    origin: .zero,
                    size: size
                )
            )
        )
    }

    var sprite: Sprite {
        Sprite(
            position: entity.position,
            size: entity.size,
            material: .sprite(
                timeline.animation.textureID,
                sourceRect: timeline.frame
            )
        )
    }

    public mutating func place(in worldSize: Vec2) {
        entity.position = .init(
            x: (worldSize.x - size.x) / 2,
            y: (worldSize.y - size.y) / 2
        )
    }

    public mutating func update(context: inout Game.Context) {
        let input = context.input

        timeline.speed = 0.5
        timeline.update(delta: context.delta)

        defer {
            wasJumpPressed = input.jump
        }

        let velocity = Vec2(
            x: velocity(
                current: entity.velocity.x,
                input: input.horizontal,
                delta: context.delta
            ),
            y: velocity(
                current: entity.velocity.y,
                input: input.vertical,
                delta: context.delta
            )
        )

        context.move(entity: &entity, velocity: velocity)

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

private extension SpriteAnimation {
    static let walk: SpriteAnimation = .init(
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

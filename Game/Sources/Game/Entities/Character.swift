import Pixl
import Pixl2D

struct Character: Entity {
    private var sprite: Sprite
    private let sheet: SpriteSheet

    private let idle: SpriteAnimation
    private let walk: SpriteAnimation
    private var timeline: SpriteAnimation.Timeline

    private var position: Vec2 = .zero
    private var velocity: Vec2 = .zero

    var bounds: Rect {
        .init(center: position, size: sprite.size)
    }

    private let bindings: PlayerBindings = .init()
    private let controller: AxisController = .init(
        maxSpeed: 300,
        acceleration: 1000,
        deceleration: 1000
    )

    init(context: GameContext) throws {
        sprite = try .init(
            named: "character.png",
            context: context
        )

        sheet = SpriteSheet(
            asset: sprite.asset,
            columns: 3,
            rows: 4
        )

        idle = .init(
            frames: sheet[row: 0, columns: ...1],
            frameDuration: 0.3
        )

        walk = .init(
            frames: sheet[row: 2],
            frameDuration: 0.2
        )

        timeline = .init(animation: idle)
        sprite.region = timeline.region
        sprite.layer = .entity

        bindings.bind(to: context.inputs)
    }

    mutating func update(_ time: UpdateTime, context: GameContext) {
        timeline.advance(by: time.delta)
        sprite.region = timeline.region

        let target = bindings.velocity

        velocity = controller.velocity(
            source: velocity,
            target: target,
            delta: time.delta
        )

        position += velocity * Float(time.delta)

        if velocity.x > 0 {
            sprite.isFlipped = false
            timeline.animation = walk
        } else if velocity.x < 0 {
            sprite.isFlipped = true
            timeline.animation = walk
        } else {
            timeline.animation = idle
        }
    }

    func submit(to queue: RenderQueue) {
        queue.submit(
            sprite,
            transform: .init(position)
        )
    }
}

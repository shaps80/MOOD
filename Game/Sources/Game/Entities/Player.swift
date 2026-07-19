import Pixl
import Pixl2D

struct Player: Entity {
    private var sprite: Sprite
    private var animation: SpriteAnimation.Timeline
    private let camera: OrthographicCamera

    private var position: Vec2 = .zero
    private var velocity: Vec2 = .zero

    private let bindings: PlayerBindings = .init()
    private let controller: AxisController = .init(
        maxSpeed: 300,
        acceleration: 1000,
        deceleration: 1000
    )

    init(camera: OrthographicCamera, context: GameContext) throws {
        self.camera = camera

        sprite = try .init(
            named: "player.png",
            context: context
        )
        let sheet = SpriteSheet(
            asset: sprite.asset,
            columns: 4,
            rows: 1
        )
        animation = SpriteAnimation.Timeline(
            animation: SpriteAnimation(
                frames: sheet.regions,
                frameDuration: 0.125
            )
        )
        sprite.region = animation.region
        sprite.layer = .player

        bindings.bind(to: context.inputs)
    }

    mutating func update(_ time: UpdateTime, context: GameContext) {
        animation.advance(by: time.delta)
        sprite.region = animation.region
        let target = bindings.velocity

        velocity = controller.velocity(
            source: velocity,
            target: target,
            delta: time.delta
        )

        position += velocity * time.delta

        if velocity.x > 0 {
            sprite.isFlipped = false
        } else if velocity.x < 0 {
            sprite.isFlipped = true
        }
    }

    func submit(
        to renderer: SpriteRenderer,
        output: RenderTarget,
    ) {
        renderer.submit(
            sprite,
            transform:
                camera
                .projection(for: output)
                .translated(by: position)
        )
    }
}

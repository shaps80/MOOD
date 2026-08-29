import Pixl
import Pixl2D

struct Character: Entity {
    private var sprite: Sprite
    private let sheet: SpriteSheet

    private let idle: SpriteAnimation
    private let walk: SpriteAnimation
    private var timeline: SpriteAnimation.Timeline

    private var editable = Editable2D(rotation: .pi / 4)
    private var velocity: Vec2 = .zero
    private let camera: OrthographicCamera

    private let bindings: PlayerBindings = .init()
    private let controller: AxisController = .init(
        maxSpeed: 300,
        acceleration: 1000,
        deceleration: 1000
    )

    init(
        camera: OrthographicCamera,
        context: GameContext
    ) throws {
        self.camera = camera

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
        editable.size = sprite.size

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

        editable.position += velocity * Float(time.delta)

        if velocity.x > 0 {
            sprite.isFlipped = false
            timeline.animation = walk
        } else if velocity.x < 0 {
            sprite.isFlipped = true
            timeline.animation = walk
        } else {
            timeline.animation = idle
        }

        editable.size = sprite.size
        editable.update(camera: camera, context: context)
    }

    func submit(to queue: RenderQueue, context: GameContext) {
        queue.submit(
            sprite,
            transform: editable.transform
        )
        editable.drawGizmo(context: context)
    }
}

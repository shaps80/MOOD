import Pixl
import Pixl2D

struct Character: Entity {
    private var sprite: Sprite
    private let sheet: SpriteSheet

    private let idle: SpriteAnimation
    private let walk: SpriteAnimation
    private var timeline: SpriteAnimation.Timeline
    private var isFlipped: Bool = true

    private var editable = Editable()
    private var velocity: Vec2 = .zero
    private let camera: OrthographicCamera
    private let rendering = RenderProperties(layer: .entity)

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
        editable.size = sprite.size

        bindings.bind(to: context.inputs)
    }

    var bounds: Rect {
        Rect(center: editable.position, size: editable.size)
    }

    mutating func fixedUpdate(_ time: FixedTime, context: GameContext) {
        velocity = controller.velocity(
            source: velocity,
            target: bindings.velocity,
            delta: time.delta
        )

        editable.position += velocity * Float(time.delta)
    }

    mutating func update(_ time: UpdateTime, context: GameContext) {
        timeline.advance(by: time.delta)
        sprite.region = timeline.region

        if velocity.x > 0 {
            isFlipped = false
            timeline.animation = walk
        } else if velocity.x < 0 {
            isFlipped = true
            timeline.animation = walk
        } else {
            timeline.animation = idle
        }

        editable.size = sprite.size
        editable.update(camera: camera, context: context)
    }

    mutating func onCollision(
        _ collision: Collision2D,
        collider: ColliderID,
        context: GameContext
    ) -> Rect? {
        guard collision.source.collider == collider else { return nil }
        if let contact = collision.contact {
            editable.position -= contact.normal * contact.depth
        }
        return bounds
    }

    func submit(to queue: RenderQueue, context: GameContext) {
        queue.submit(
            sprite,
            transform: editable.transform
                .scaled(x: isFlipped ? -1 : 1, y: 1),
            rendering: rendering
        )
        editable.drawGizmo(context: context)
    }
}

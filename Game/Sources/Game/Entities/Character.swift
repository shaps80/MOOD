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
    private var controller: PlatformerController
    private let camera: OrthographicCamera
    private let rendering = RenderProperties(layer: .entity)

    private let bindings: PlayerBindings = .init()

    init(
        camera: OrthographicCamera,
        context: GameContext
    ) throws {
        self.camera = camera

        sprite = try .init(
            named: "character",
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
        controller = .init(
            configuration: .flexible(scale: sprite.size.y)
        )

        bindings.bind(to: context.inputs)
    }

    var bounds: Rect {
        Rect(center: editable.position, size: editable.size)
    }

    mutating func fixedUpdate(_ time: FixedTime, context: GameContext) {
        captureInput()
        editable.position += controller.advance(delta: Float(time.delta))
    }

    mutating func update(_ time: UpdateTime, context: GameContext) {
        captureInput()
        timeline.advance(by: time.delta)
        sprite.region = timeline.region

        isFlipped = !controller.isFacingRight
        switch controller.state {
        case .walking, .running, .crouchWalking, .crouchRolling:
            timeline.animation = walk
        default:
            timeline.animation = idle
        }

        editable.size = sprite.size
        editable.update(camera: camera, context: context)
    }

    mutating func onCollision(
        _ collision: Collision2D,
        collider: ColliderID,
        context: GameContext
    ) -> Transform2D? {
        guard collision.source.collider == collider,
              let contact = collision.contact
        else { return nil }

        editable.position += controller.resolve(contact)

        return editable.transform
    }

    private mutating func captureInput() {
        controller.capture(
            .init(
                movement: .init(
                    bindings.right.value - bindings.left.value,
                    bindings.up.value - bindings.down.value
                ),
                jump: .init(bindings.space),
                run: .init(bindings.run),
                dash: .init(bindings.dash),
                crouch: .init(bindings.down)
            )
        )
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

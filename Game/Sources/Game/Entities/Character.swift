import Pixl
import Pixl2D

struct Character: Entity {
    private static let size: Vec2 = .init(repeating: 48)

    private let idle: AnimatedSprite
    private let walk: AnimatedSprite
    private let run: AnimatedSprite
    private let jump: AnimatedSprite
    private let dash: AnimatedSprite
    private let land: AnimatedSprite
    private let crouchIdle: AnimatedSprite
    private let crouchWalk: AnimatedSprite
    private let wallSlide: AnimatedSprite
    private let wallLand: AnimatedSprite

    private var sprite: Sprite
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

        idle = try .idle(in: context)
        walk = try .walk(in: context)
        run = try .run(in: context)
        jump = try .jump(in: context)
        dash = try .dash(in: context)
        land = try .land(in: context)
        crouchIdle = try .crouchIdle(in: context)
        crouchWalk = try .crouchWalk(in: context)
        wallSlide = try .wallSlide(in: context)
        wallLand = try .wallLand(in: context)

        sprite = idle.sprite
        timeline = .init(animation: idle.animation)

        editable.size = Self.size
        controller = .init(
            configuration: .flexible(scale: Self.size.x)
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
        case .walking:
            timeline.animation = walk.animation
        case .running:
            timeline.animation = run.animation
        case .jumping:
            timeline.animation = jump.animation
        case .dash:
            timeline.animation = dash.animation
        case .crouching:
            timeline.animation = crouchIdle.animation
        case .crouchWalking:
            timeline.animation = crouchWalk.animation
        case .wallSliding:
            timeline.animation = wallSlide.animation
        case .wallFalling:
            timeline.animation = wallLand.animation
        default:
            timeline.animation = idle.animation
        }

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

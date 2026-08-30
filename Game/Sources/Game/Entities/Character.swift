import Pixl
import Pixl2D

struct Character: Entity {
    private static let size: Vec2 = .init(repeating: 48)

    private let animations: CharacterAnimations
    private var animatedSprite: AnimatedSprite
    private var currentAnimation: CharacterAnimation = .idle

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

        let animations = try CharacterAnimations(context: context)
        self.animations = animations
        animatedSprite = .init(animation: animations.idle)

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

        isFlipped = !controller.isFacingRight

        let animation = animation(for: controller.state)
        if animation != currentAnimation {
            currentAnimation = animation
            animatedSprite.play(
                animations[animation],
                speed: animationSpeed(for: animation)
            )
        } else {
            animatedSprite.advance(by: time.delta)
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

    private func animation(for state: PlatformerState) -> CharacterAnimation {
        switch state {
        case .idle:
            .idle
        case .walking:
            .walk
        case .running:
            .run
        case .crouching:
            .crouchIdle
        case .crouchWalking, .crouchRolling:
            .crouchWalk
        case .jumping, .runJumping, .wallJumping:
            .jump
        case .falling, .runFalling, .dashFalling, .wallFalling:
            .fall
        case .dash:
            .dash
        case .wallSliding:
            .wallSlide
        }
    }

    private func animationSpeed(for animation: CharacterAnimation) -> Double {
        switch animation {
        case .dash:
            let duration = Double(controller.configuration.dash.duration)
            if duration > 0 {
                return animations.dash.duration / duration
            }
            return 1
        default:
            return 1
        }
    }

    func submit(to queue: RenderQueue, context: GameContext) {
        queue.submit(
            animatedSprite.sprite,
            transform: editable.transform
                .scaled(x: isFlipped ? -1 : 1, y: 1),
            rendering: rendering
        )
        editable.drawGizmo(context: context)
    }
}

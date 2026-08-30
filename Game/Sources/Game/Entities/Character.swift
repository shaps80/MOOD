import Pixl
import Pixl2D

struct Character: Entity {
    private static let size: Vec2 = .init(repeating: 48)
    static let referenceScale = size.y / 1.7
    static let referenceCameraHalfHeight: Float = 11.25 * referenceScale

    private let animations: CharacterAnimations
    private var animatedSprite: AnimatedSprite
    private var currentAnimation: CharacterAnimation = .idle

    private var isFlipped: Bool = true

    private var editable = Editable()
    private var controller: PlatformerController
    private var collisionProbes = PlatformerCollisionProbes()
    private let collision: ColliderID
    private let camera: OrthographicCamera
    private let rendering = RenderProperties(layer: .entity)

    private let bindings: PlayerBindings = .init()

    init(
        camera: OrthographicCamera,
        collisions: CollisionWorld2D,
        context: GameContext
    ) throws {
        self.camera = camera

        let animations = try CharacterAnimations(context: context)
        self.animations = animations
        animatedSprite = .init(animation: animations.idle)

        editable.size = Self.size
        var configuration = PlatformerConfiguration.flexible(
            scale: Self.referenceScale
        )
        configuration.collision.surfaceMask = .world
        controller = .init(configuration: configuration)
        collision = collisions.insert(
            configuration.collision.standingBody,
            mode: .dynamic,
            layer: .character,
            mask: .world
        )

        bindings.bind(to: context.inputs)
    }

    private var collider: Capsule2D {
        controller.configuration.collision.body(for: controller.stance)
    }

    private var colliderTransform: Transform2D {
        Transform2D(editable.position)
    }

    mutating func fixedUpdate(
        _ time: FixedTime,
        collisions: CollisionWorld2D,
        context: GameContext
    ) {
        captureInput()
        let surfaces = collisionProbes.update(
            stance: controller.stance,
            transform: colliderTransform,
            configuration: controller.configuration.collision,
            in: collisions
        )
        var displacement = controller.advance(
            delta: Float(time.delta),
            surfaces: surfaces
        )
        if controller.state == .dash
            || abs(controller.velocity.x)
                > controller.configuration.movement.runSpeed
        {
            displacement = collisionProbes.constrainDash(
                displacement,
                stance: controller.stance,
                transform: colliderTransform,
                configuration: controller.configuration.collision,
                in: collisions
            )
        }
        editable.position += displacement
        collisions.update(
            collision,
            capsule: collider,
            transform: colliderTransform
        )
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
        context: GameContext
    ) -> Transform2D? {
        guard collision.source.collider == self.collision,
              let contact = collision.contact
        else { return nil }

        editable.position += controller.resolve(contact)

        return colliderTransform
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

    func submit(
        to queue: RenderQueue,
        showsCollisionDebug: Bool,
        context: GameContext
    ) {
        queue.submit(
            animatedSprite.sprite,
            transform: editable.transform
                .scaled(x: isFlipped ? -1 : 1, y: 1),
            rendering: rendering
        )
        editable.drawGizmo(context: context)
        if showsCollisionDebug {
            collisionProbes.submitDebug(
                stance: controller.stance,
                transform: colliderTransform,
                configuration: controller.configuration.collision,
                layer: .gizmo,
                to: queue,
                context: context
            )
        }
    }

    func submit(to queue: RenderQueue, context: GameContext) {
        submit(
            to: queue,
            showsCollisionDebug: false,
            context: context
        )
    }
}

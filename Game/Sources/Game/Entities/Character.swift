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
    private var horizontalVelocity: Float = 0
    private var isGrounded = false
    private var jumpBufferRemaining: Float = 0
    private var coyoteTimeRemaining: Float = 0
    private var isJumpPressCaptured = false
    private let camera: OrthographicCamera
    private let rendering = RenderProperties(layer: .entity)

    private let gravity: Float = -1_200
    private let jumpSpeed: Float = 500
    private let minimumGroundNormalY: Float = 0.7
    private let jumpBufferDuration: Float = 0.12
    private let coyoteTimeDuration: Float = 0.1

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

        bindings.bind(to: context.inputs)
    }

    var bounds: Rect {
        Rect(center: editable.position, size: editable.size)
    }

    mutating func fixedUpdate(_ time: FixedTime, context: GameContext) {
        captureJumpInput()

        let canJump = isGrounded || coyoteTimeRemaining > 0
        isGrounded = false

        horizontalVelocity = controller.velocity(
            source: horizontalVelocity,
            target: bindings.right.value - bindings.left.value,
            delta: time.delta
        )
        velocity.x = horizontalVelocity

        if canJump, jumpBufferRemaining > 0 {
            velocity.y = jumpSpeed
            jumpBufferRemaining = 0
            coyoteTimeRemaining = 0
        }

        let delta = Float(time.delta)
        velocity.y += gravity * delta

        editable.position += velocity * delta

        jumpBufferRemaining = max(0, jumpBufferRemaining - delta)
        coyoteTimeRemaining = max(0, coyoteTimeRemaining - delta)
    }

    mutating func update(_ time: UpdateTime, context: GameContext) {
        captureJumpInput()
        timeline.advance(by: time.delta)
        sprite.region = timeline.region

        if horizontalVelocity > 0 {
            isFlipped = false
            timeline.animation = walk
        } else if horizontalVelocity < 0 {
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
    ) -> Transform2D? {
        guard collision.source.collider == collider,
              let contact = collision.contact
        else { return nil }

        editable.position -= contact.normal * contact.depth

        let inwardSpeed = velocity.dot(contact.normal)
        if inwardSpeed > 0 {
            velocity -= contact.normal * inwardSpeed
        }

        let surfaceNormal = -contact.normal
        if surfaceNormal.y >= minimumGroundNormalY {
            isGrounded = true
            coyoteTimeRemaining = coyoteTimeDuration
        }

        return editable.transform
    }

    private mutating func captureJumpInput() {
        guard bindings.space.is(.down) else {
            isJumpPressCaptured = false
            return
        }
        guard !isJumpPressCaptured else { return }

        isJumpPressCaptured = true
        jumpBufferRemaining = jumpBufferDuration
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

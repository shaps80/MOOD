import Pixl
import Pixl2D

struct Player: Entity {
    private var sprite: Sprite
    private let camera = OrthographicCamera(halfHeight: 200)

    private var position = Vec2.zero
    private var velocity: Vec2 = .zero
    private let bindings: PlayerBindings = .init()
    private let controller: AxisController = .init(
        maxSpeed: 300,
        acceleration: 1000,
        deceleration: 1000
    )

    private var elapsed: Double = 0

    init(
        pipeline: RenderPipeline,
        audio: GameAudio,
        context: GameContext
    ) throws {
        sprite = try .init(
            named: "player.png",
            pipeline: pipeline,
            context: context
        )

        bindings.bind(to: context.inputs)
    }

    mutating func update(_ time: UpdateTime, context: GameContext) {
        elapsed = time.elapsedSeconds
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

    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame,
        time: RenderTime,
        context: GameContext
    ) throws {
        sprite.draw(
            frame: frame,
            output: output,
            transform: camera
                .projection(for: output)
                .translated(by: position)
        )
    }
}

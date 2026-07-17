import Pixl
import Pixl2D

struct Player: Entity {
    private var sprite: Sprite
    private let camera = OrthographicCamera(halfHeight: 200)

    private var position = Vec2.zero
    private var velocity: Vec2 = .zero
    private let controller: AxisController = .init(
        maxSpeed: 300,
        acceleration: 1000,
        deceleration: 1000
    )

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
    }

    mutating func update(_ time: UpdateTime, context: GameContext) {
        let key: Vec2 = .init(
            x: (context.keyboard.contains(.d) ? 1.0 : 0)
            - (context.keyboard.contains(.a) ? 1.0 : 0),
            y: (context.keyboard.contains(.w) ? 1 : 0)
            - (context.keyboard.contains(.s) ? 1 : 0)
        )

        let stick = context.gamepads.first?.leftStick ?? .zero
        let deadzone = 0.12

        let x, y: Double

        if abs(stick.x) >= deadzone || abs(stick.y) >= deadzone {
            x = stick.x
            y = stick.y
        } else {
            x = key.x
            y = key.y
        }

        velocity.x = controller.velocity(
            current: velocity.x,
            input: x,
            delta: time.delta
        )

        velocity.y = controller.velocity(
            current: velocity.y,
            input: y,
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

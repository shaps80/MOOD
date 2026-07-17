import Pixl
import Pixl2D

struct Player: Entity {
    private let sprite: Sprite
    private let camera = OrthographicCamera(halfHeight: 1)
    private var position = Vec2.zero
    private var velocity: Vec2 = .zero

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
        if let key = context.keyboard.key(.a, phase: .down), !key.isRepeat {
            velocity.x -= 1
        }

        if let key = context.keyboard.key(.d, phase: .down), !key.isRepeat {
            velocity.x += 1
        }

        position += velocity
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

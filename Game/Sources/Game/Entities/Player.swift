import Pixl
import Pixl2D

struct Player: Entity {
    private var sprite: Sprite
    private var animation: SpriteAnimation.Timeline
    private let camera: OrthographicCamera
    private var position: Vec2 = .init(96, 0)

    init(camera: OrthographicCamera, context: GameContext) throws {
        self.camera = camera

        sprite = try .init(
            named: "player.png",
            context: context
        )
        let sheet = SpriteSheet(
            asset: sprite.asset,
            columns: 4,
            rows: 1
        )
        animation = SpriteAnimation.Timeline(
            animation: SpriteAnimation(
                frames: sheet.regions,
                frameDuration: 0.3
            )
        )

        sprite.region = animation.region
        sprite.layer = .character
        sprite.isFlipped = true
    }

    mutating func update(_ time: UpdateTime, context: GameContext) {
        animation.advance(by: time.delta)
        sprite.region = animation.region
    }

    func submit(
        to renderer: SpriteRenderer,
        output: RenderTarget,
    ) {
        renderer.submit(
            sprite,
            transform:
                camera
                .projection(for: output)
                .translated(by: position)
        )
    }
}

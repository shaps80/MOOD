import Pixl
import Pixl2D

struct Character: Entity {
    private var sprite: Sprite
    private var animation: SpriteAnimation.Timeline
    private var camera: OrthographicCamera
    private var position: Vec2 = .zero

    init(camera: OrthographicCamera, context: GameContext) throws {
        self.camera = camera
        sprite = try .init(named: "character.png", context: context)
        sprite.layer = .character

        let sheet = SpriteSheet(
            asset: sprite.asset,
            columns: 3,
            rows: 4
        )

        animation = .init(
            animation: .init(
                frames: sheet[row: 2, columns: 0...2],
                frameDuration: 0.125
            )
        )
        sprite.region = animation.region
    }

    mutating func update(_ time: UpdateTime, context: GameContext) {
        animation.advance(by: time.delta)
        sprite.region = animation.region
    }

    func submit(to renderer: SpriteRenderer, output: RenderTarget) {
        renderer.submit(sprite, transform: camera.projection(for: output).translated(by: position))
    }
}

import Pixl
import Pixl2D

struct Player: Entity {
    private var sprite: Sprite
    private var animation: SpriteAnimation.Timeline
    private var position: Vec2 = .init(96, 0)

    private var shape: Shape

    init(context: GameContext) throws {
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
        sprite.layer = .entity
        sprite.isFlipped = true
        sprite.order = 1

        /**
         blobbyCross
         cross
         equilateralTriangle

         inside shows fill bleed
         outside has a "gap" 0.5px maybe
         */

        shape = Shape(.ring)
            .fill(.red)
//            .stroke(.green, width: 0.05, alignment: .inside)

        shape.layer = .shape
    }

    mutating func update(_ time: UpdateTime, context: GameContext) {
        animation.advance(by: time.delta)
        sprite.region = animation.region
    }

    func submit(to queue: RenderQueue) {
        queue.submit(
            shape,
            transform: .identity
        )

//        queue.submit(
//            sprite,
//            transform: .init(position)
//        )
    }
}

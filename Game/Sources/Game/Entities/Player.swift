import Pixl
import Pixl2D

struct Player {
    private var sprite: Sprite
    private var animation: SpriteAnimation.Timeline
    private let positions: SpatialGrid

    init(count: Int, worldSize: Float, context: GameContext) throws {
        positions = SpatialGrid(
            count: count,
            worldSize: worldSize,
            cellSize: 200
        )

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
    }

    mutating func update(_ time: UpdateTime, context: GameContext) {
        animation.advance(by: time.delta)
        sprite.region = animation.region
    }

    mutating func fixedUpdate(_ time: FixedTime, context: GameContext) { }

    func submit(visibleBounds: Rect, to queue: RenderQueue) -> Int {
        positions.forEachPosition(in: visibleBounds, cellPadding: 1) {
            queue.submit(sprite, transform: .init($0))
        }
    }
}

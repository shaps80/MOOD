import Pixl
import Pixl2D

struct AnimatedSprite: Sendable {
    private var sheet: SpriteSheet
    private(set) var sprite: Sprite
    private(set) var animation: SpriteAnimation

    init(named name: String, frames count: Int, duration: Double = 1 / 12, context: GameContext) throws {
        sprite = try .init(named: name, context: context)
        sheet = .init(asset: sprite.asset, columns: count, rows: 1)

        animation = SpriteAnimation(
            frames: sheet[row: 0, columns: 0 ... count - 1],
            frameDuration: duration
        )
    }
}

extension AnimatedSprite {
    static func idle(in context: GameContext) throws -> Self {
        try .init(
            named: "player/player-idle",
            frames: 10,
            context: context
        )
    }

    static func walk(in context: GameContext) throws -> Self {
        try .init(
            named: "player/player-walk",
            frames: 8,
            context: context
        )
    }

    static func run(in context: GameContext) throws -> Self {
        try .init(
            named: "player/player-run",
            frames: 8,
            context: context
        )
    }

    static func land(in context: GameContext) throws -> Self {
        try .init(
            named: "player/player-land",
            frames: 9,
            context: context
        )
    }

    static func crouchIdle(in context: GameContext) throws -> Self {
        try .init(
            named: "player/player-crouch-idle",
            frames: 10,
            context: context
        )
    }

    static func crouchWalk(in context: GameContext) throws -> Self {
        try .init(
            named: "player/player-crouch-walk",
            frames: 10,
            context: context
        )
    }

    static func dash(in context: GameContext) throws -> Self {
        try .init(
            named: "player/player-dash",
            frames: 9,
            context: context
        )
    }

    static func jump(in context: GameContext) throws -> Self {
        try .init(
            named: "player/player-jump",
            frames: 6,
            context: context
        )
    }

    static func wallSlide(in context: GameContext) throws -> Self {
        try .init(
            named: "player/player-wall-slide",
            frames: 3,
            context: context
        )
    }

    static func wallLand(in context: GameContext) throws -> Self {
        try .init(
            named: "player/player-wall-land",
            frames: 6,
            context: context
        )
    }
}

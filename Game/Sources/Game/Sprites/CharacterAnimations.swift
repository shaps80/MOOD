import Pixl
import Pixl2D

struct CharacterAnimations: Sendable {
    let idle: SpriteAnimation
    let walk: SpriteAnimation
    let run: SpriteAnimation
    let jump: SpriteAnimation
    let fall: SpriteAnimation
    let dash: SpriteAnimation
    let crouchIdle: SpriteAnimation
    let crouchWalk: SpriteAnimation
    let wallSlide: SpriteAnimation
    let land: SpriteAnimation
    let wallLand: SpriteAnimation

    init(context: GameContext) throws {
        func load(
            _ name: String,
            frames count: Int,
            loops: Bool = true
        ) throws -> SpriteAnimation {
            let sprite = try Sprite(named: name, context: context)
            let sheet = SpriteSheet(
                asset: sprite.asset,
                columns: count,
                rows: 1
            )
            return SpriteAnimation(
                frames: sheet[row: 0],
                frameDuration: 1 / 12,
                loops: loops
            )
        }

        idle = try load("player/player-idle", frames: 10)
        walk = try load("player/player-walk", frames: 8)
        run = try load("player/player-run", frames: 8)
        dash = try load("player/player-dash", frames: 9, loops: false)
        land = try load("player/player-land", frames: 9, loops: false)
        crouchIdle = try load("player/player-crouch-idle", frames: 10)
        crouchWalk = try load("player/player-crouch-walk", frames: 10)
        wallSlide = try load(
            "player/player-wall-slide",
            frames: 3,
            loops: false
        )
        wallLand = try load(
            "player/player-wall-land",
            frames: 6,
            loops: false
        )

        let jumpSprite = try Sprite(
            named: "player/player-jump",
            context: context
        )
        let jumpSheet = SpriteSheet(
            asset: jumpSprite.asset,
            columns: 6,
            rows: 1
        )
        jump = .init(
            frames: jumpSheet[row: 0],
            frameDuration: 1 / 12,
            loops: false
        )
        fall = .init(
            frames: jumpSheet[row: 0, columns: 3 ... 5],
            frameDuration: 1 / 12,
            loops: false
        )
    }

    subscript(animation: CharacterAnimation) -> SpriteAnimation {
        switch animation {
        case .idle: idle
        case .walk: walk
        case .run: run
        case .jump: jump
        case .fall: fall
        case .dash: dash
        case .crouchIdle: crouchIdle
        case .crouchWalk: crouchWalk
        case .wallSlide: wallSlide
        case .land: land
        case .wallLand: wallLand
        }
    }
}

import Pixl
import PlatformMac

private var game: Pixl.Game {
    .init(
        "Retro Invaders",
        size: GameConfig.resolution,
        world: .spaceInvaders
    )
}

PlatformMac.run(game: game)

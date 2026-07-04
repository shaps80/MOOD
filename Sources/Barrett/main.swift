import Pixl
import PlatformMac

private var game: Pixl.Game {
    .init(
        "Barrett",
        size: GameConfig.resolution,
        world: .spaceInvaders,
    )
}

PlatformMac.run(game: game)

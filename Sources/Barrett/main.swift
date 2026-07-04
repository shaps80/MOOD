import Pixl

private var game: Pixl.Game {
    .init(
        "Retro Invaders",
        size: GameConfig.resolution,
        world: .spaceInvaders
    )
}

#if os(macOS)
import PlatformMac
PlatformMac.run(game: game)
#else
import PlatformWeb
PlatformWeb.run(game: game)
#endif

import Pixl
import Pixl2D

@main
struct Game: Pixl.Game {
    private let world: World

    static var gameSettings: GameSettings {
        .init(
            title: "Pixl",
            resolution: .init(width: 800, height: 400)
        )
    }

    init(context: GameContext) throws {
        let world = context.register(World())
        let players = world.register(Player.self, capacity: 4)

        _ = players.spawn(
            try Player(
                device: context.platform.device,
                drawableFormat: Self.renderSettings.drawableFormat
            )
        )
        self.world = world
    }
}

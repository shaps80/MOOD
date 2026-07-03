import Pixl
import PlatformMac

let size: Vec2 = .init(x: 1600, y: 900)

struct Player: Entity {
    private var controller: TopPlayerController = .default

    func prepare(context: inout Game.PreparationContext, state: inout EntityState) {
        state.sprite = .init(
            material: .shape(
                RoundedRectangle(cornerRadius: 10),
                size: .init(24)
            )
        )
        state.sprite?.tint = .blue
        state.position = .init(
            x: (size.x - 24) / 2,
            y: (size.y - 24) / 2
        )
    }

    func onUpdate(context: inout Game.Context, state: inout EntityState) {
        state.rotation += .degrees(180) * context.delta
        state.velocity = controller.velocity(
            for: context.input,
            current: state.velocity,
            delta: context.delta
        )
    }
}

private var world: World {
    var world: World = .init(
        level: .init(
            assets: .init(
                sprites: [],
                sounds: []
            ),
            markers: [.init(
                kind: Player.kind,
                position: .init(
                    x: 16 * 2,
                    y: 16 * 2
                )
            )]
        )
    )

    world.register(Player.self)
    return world
}

private var game: Pixl.Game {
    .init("Barrett", size: size, world: world)
}

PlatformMac.run(game: game)

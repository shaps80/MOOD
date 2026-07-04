import Pixl
import PlatformMac

let resolution: Vec2 = .init(x: 640, y: 320)

struct Enemy: Entity {
    static let size: Double = 24

    func prepare(context: inout Game.PreparationContext, state: inout EntityState) {
        state.sprite = .init(
            material: .shape(
                Circle(),
                size: .init(Self.size)
            ),
            tint: .red
        )
    }

    func onUpdate(context: inout Game.Context, state: inout EntityState) { }
}

struct Player: Entity {
    static let size: Double = 24
    private var controller: TopPlayerController = .init(
        horizontal: AxisController(
            maxSpeed: 300,
            acceleration: 1000,
            deceleration: 1000
        ),
        vertical: AxisController(
            maxSpeed: 300,
            acceleration: 1000,
            deceleration: 1000
        )
    )
    private var spawnedEnemy: Bool = false

    func prepare(context: inout Game.PreparationContext, state: inout EntityState) {
        state.sprite = .init(
            material: .shape(
                RoundedRectangle(cornerRadius: 10),
                size: .init(Self.size)
            )
        )
        state.sprite?.tint = .blue
        state.transform.position = .init(
            x: (resolution.x - Self.size) / 2,
            y: (resolution.y - Self.size) / 2
        )
    }

    mutating func onUpdate(context: inout Game.Context, state: inout EntityState) {
        if context.input.jump {
            state.transform.rotation += .degrees(
                180 * context.input.direction.x
            ) * context.delta
        }

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
    .init("Barrett", size: resolution, world: world)
}

PlatformMac.run(game: game)

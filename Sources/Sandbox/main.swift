#if os(WASI)
import PlatformWeb
#endif
#if os(macOS)
import PlatformMac
#endif

import Pixl

extension World {
    static func makeDefault(size: Vec2) -> Self {
        let level: OldLevel = .level2(
            tileSize: Vec2(x: 16, y: 16)
        )

        let camera: CameraRig = .init(
            camera: Camera(viewportSize: size),
            anchor: .entities([.player]),
            constraints: .init(bounds: level.bounds)
        )

        var world: World = .init(
            level: .init(
                assets: .init(
                    sprites: [.player],
                    sounds: [.jump]
                ),
                tilemap: level.tilemap,
                markers: [
                    .init(
                        kind: Player.kind,
                        position: level.spawnPoint
                    ),
                    .init(
                        kind: Enemy.kind,
                        position: .init(x: 64, y: 64)
                    ),
                    .init(
                        kind: Pickup.kind,
                        position: .init(
                            x: level.spawnPoint.x + (level.tilemap.tileSize.x * 8),
                            y: level.spawnPoint.y
                        )
                    ),
                    .init(
                        kind: Slope.kind,
                        position: .init(
                            x: level.spawnPoint.x + (level.tilemap.tileSize.x * 8),
                            y: level.spawnPoint.y + (level.tilemap.tileSize.y * 3)
                        )
                    )
                ]
            ),
            camera: camera
        )

        world.register(
            Player.self,
            Enemy.self,
            Pickup.self,
            Slope.self
        )

        return world
    }
}

private var size: Vec2 {
    .init(x: 800, y: 400)
}

private var game: Game {
    .init(
        "Pixl",
        size: size,
        clearColor: .white,
        interpolationMode: .nearest,
        preferredFPS: 60,
        world: .makeDefault(size: size)
    )
}

#if os(macOS)
    import PlatformMac
    PlatformMac.run(game: game)
#elseif os(WASI)
    import PlatformWeb
    PlatformWeb.run(game: game)
#else
    print("This platform is not currently supported!")
#endif

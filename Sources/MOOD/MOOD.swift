#if os(WASI)
import PlatformWeb
#endif
#if os(macOS)
import PlatformMac
#endif

import Pixl

@main
struct MOOD {
    private static var game: Game {
        let size = Vec2(x: 800, y: 400)

        let level: OldLevel = .level2(
            worldSize: Vec2(
                x: size.x * 2,
                y: size.y
            ),
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
                    )
                ]
            ),
            camera: camera
        )

        world.register(
            Player.self,
            Enemy.self,
            Pickup.self
        )

        return .init(
            size: size,
            interpolationMode: .nearest,
            preferredFPS: 60,
            world: world
        )
    }

#if os(macOS)
    @MainActor
    static func main() {
        PlatformMac.run(game: game)
    }
#else
    static func main() {
#if os(WASI)
        PlatformWeb.run(game: game)
#else
        print("This platform is not currently supported!")
#endif
    }
#endif
}

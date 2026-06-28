#if os(WASI)
import PlatformWeb
#endif
#if os(macOS)
import PlatformMac
#endif

import Pixl

@main
struct MOOD {
    private static let size: Vec2 = .init(
        x: 1920,
        y: 1080
    )

    private static var level: Level {
        .level2(
            worldSize: Vec2(
                x: size.x * 2,
                y: size.y
            ),
            tileSize: Vec2(x: 16, y: 16)
        )
    }

    private static var game: Game {
        let level = level
        return .init(
            size: size,
            interpolationMode: .nearest,
            preferredFPS: 60,
            level: level,
            camera: .init(
                camera: Camera(viewportSize: size),
                anchor: .entities([.player]),
                constraints: .init(bounds: level.bounds)
            ),
            entities: [
                .init(
                    id: .pickup,
                    entity: Pickup(),
                    position: Vec2(
                        x: level.spawnPoint.x + (level.tilemap.tileSize.x * 8),
                        y: level.spawnPoint.y
                    )
                ),
                .init(
                    id: .enemy,
                    entity: Enemy(),
                    position: .init(
                        x: 64,
                        y: 64
                    )
                ),
                .init(
                    id: .player,
                    entity: Player(),
                    position: level.spawnPoint
                ),
            ],
            sprites: [.player],
            sounds: [.jump]
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

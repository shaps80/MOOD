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
        x: 800,
        y: 400
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
        let pickup = Pickup()

        return .init(
            size: size,
            interpolationMode: .nearest,
            preferredFPS: 60,
            level: level,
            camera: .init(
                camera: Camera(viewportSize: size),
                anchor: .entities([.player]),
                constraints: CameraConstraints(bounds: level.bounds)
            ),
            entities: [
                .init(
                    id: .pickup,
                    entity: pickup,
                    position: origin(
                        center: Vec2(
                            x: level.spawnPoint.x + (level.tilemap.tileSize.x * 8),
                            y: level.spawnPoint.y
                        ),
                        size: pickup.size
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
            ]
        )
    }

    private static func origin(center: Vec2, size: Vec2) -> Vec2 {
        Vec2(
            x: center.x - (size.x / 2),
            y: center.y - (size.y / 2)
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

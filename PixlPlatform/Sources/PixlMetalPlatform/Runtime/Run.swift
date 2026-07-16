#if os(macOS)
@preconcurrency import AppKit
import PixlPlatform

@MainActor
public func run<Game: PlatformGame>(_ game: Game.Type) {
    let application = NSApplication.shared

    let runtime: Runtime = .init(
        gameSettings: Game.gameSettings,
        renderSettings: Game.renderSettings,
        makeGame: { platform in
            try Game(platform: platform)
        }
    )

    runtime.start()

    withExtendedLifetime(runtime) {
        application.run()
    }
}
#endif

#if os(macOS)
@preconcurrency import AppKit
import PixlPlatform

@MainActor
public func run(
    _ game: any PlatformGame,
    gameSettings: GameSettings,
    renderSettings: RenderSettings
) {
    let application = NSApplication.shared
    let runtime: Runtime = .init(
        game: game,
        gameSettings: gameSettings,
        renderSettings: renderSettings
    )

    runtime.start()

    withExtendedLifetime(runtime) {
        application.run()
    }
}
#endif

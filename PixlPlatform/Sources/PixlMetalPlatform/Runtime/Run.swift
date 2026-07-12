#if os(macOS)
@preconcurrency import AppKit
import PixlPlatform

@MainActor
public func run<Game: PlatformGame>(_ game: Game.Type) {
    let application = NSApplication.shared

    let runtime: Runtime = .init(
        game: Game(),
        gameSettings: Game.gameSettings,
        renderSettings: Game.renderSettings) {
            try $0.shaders.append(Game.defaultShaders)
        }

    runtime.start()

    withExtendedLifetime(runtime) {
        application.run()
    }
}
#endif

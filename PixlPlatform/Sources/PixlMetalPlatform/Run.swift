#if os(macOS)
@preconcurrency import AppKit
import PixlPlatform

@MainActor
public func run(
    _ game: any PlatformGame,
    renderSettings: RenderSettings
) {
    let application = NSApplication.shared
    let runtime: Runtime = .init(game: game, renderSettings: renderSettings)

    runtime.start()

    withExtendedLifetime(runtime) {
        application.run()
    }
}
#endif

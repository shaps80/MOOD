#if os(macOS)
@preconcurrency import AppKit
import PixlPlatform

@MainActor
public func run(_ game: any PlatformGame) {
    let application = NSApplication.shared
    let runtime: Runtime = .init(game: game)

    runtime.start()

    withExtendedLifetime(runtime) {
        application.run()
    }
}
#endif

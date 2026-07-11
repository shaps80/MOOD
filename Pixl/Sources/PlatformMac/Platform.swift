@preconcurrency import AppKit
import Pixl
import Swift

public enum PlatformMac {
    @MainActor
    public static func run(game: Game) {
        let application = NSApplication.shared
        let runtime = Runtime(game: game)

        runtime.start()

        withExtendedLifetime(runtime) {
            application.run()
        }
    }
}

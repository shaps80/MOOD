@preconcurrency import AppKit
import GameCore
import Swift

public enum PlatformMac {
    @MainActor
    public static func run() {
        let application = NSApplication.shared
        let runtime = Runtime(game: Game())

        runtime.start()

        withExtendedLifetime(runtime) {
            application.run()
        }
    }
}

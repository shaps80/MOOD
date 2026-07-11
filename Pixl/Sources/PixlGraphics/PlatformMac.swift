import PixlPlatform

#if os(macOS)
@preconcurrency import AppKit

public enum PlatformMac {
    @MainActor
    public static func run() {
        let application = NSApplication.shared
        let runtime: Runtime = .init()

        runtime.start()

        withExtendedLifetime(runtime) {
            application.run()
        }
    }
}

#endif

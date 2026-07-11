#if os(macOS)
@preconcurrency import AppKit

@MainActor
public func run() {
    let application = NSApplication.shared
    let runtime: Runtime = .init()

    runtime.start()

    withExtendedLifetime(runtime) {
        application.run()
    }
}
#endif

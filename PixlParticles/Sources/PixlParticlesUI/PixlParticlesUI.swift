@preconcurrency import AppKit

@main
enum PixlParticlesUI {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let runtime = ApplicationRuntime()

        runtime.start()

        withExtendedLifetime(runtime) {
            application.run()
        }
    }
}

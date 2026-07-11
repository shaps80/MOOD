@preconcurrency import AppKit
@preconcurrency import MetalKit

@MainActor
final class Runtime: NSObject {
    private let device: MTLDevice
    private var window: NSWindow?
    private var gameView: GameView?

    override init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not available")
        }

        self.device = device
        super.init()
    }

    func start() {
        configureApplication()
        configureWindow()
    }

    private func configureApplication() {
        let application = NSApplication.shared
        application.setActivationPolicy(.regular)
        application.mainMenu = makeMainMenu()
    }

    private func configureWindow() {
        let contentSize = NSSize(
            width: CGFloat(640),
            height: CGFloat(320)
        )
        let contentRect = NSRect(origin: .zero, size: contentSize)
        let view = GameView(
            frame: contentRect,
            device: device
        )
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .resizable
            ],
            backing: .buffered,
            defer: false
        )

        view.delegate = self
        view.preferredFramesPerSecond = 60

        window.title = "Pixl"
        window.contentView = view
        window.contentAspectRatio = contentSize
        window.contentMinSize = NSSize(width: 320, height: 180)

        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)

        self.window = window
        self.gameView = view

        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()
        let applicationMenuItem = NSMenuItem()
        let applicationMenu = NSMenu()
        let quitItem = NSMenuItem(
            title: "Quit Pixl",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        quitItem.target = NSApplication.shared
        applicationMenu.addItem(quitItem)
        applicationMenuItem.submenu = applicationMenu
        mainMenu.addItem(applicationMenuItem)

        return mainMenu
    }

    private var lastFrameTime: CFTimeInterval?
    private var accumulatedTime = 0.0
    private var fixedTimeStep: Double { 1.0 / 60 }
    private var frame = 0
}

extension Runtime: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        print("Frame \(frame)")
        frame += 1
    }
}

extension Runtime: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApplication.shared.terminate(nil)
    }
}

@preconcurrency import AppKit
@preconcurrency import MetalKit
import PixlPlatform

final class Runtime: NSObject {
    private let device: MTLDevice
    private let frame: Frame
    private let game: any PlatformGame
    private let gameSettings: GameSettings
    private let renderSettings: RenderSettings
    private var platform: MetalPlatform?
    private var window: NSWindow?
    private var gameView: GameView?

    init(
        game: any PlatformGame,
        gameSettings: GameSettings,
        renderSettings: RenderSettings
    ) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not available")
        }

        self.device = device
        frame = Frame(passCapacity: renderSettings.framePassCapacity)
        self.game = game
        self.gameSettings = gameSettings
        self.renderSettings = renderSettings
        super.init()
    }

    @MainActor
    func start() {
        configureApplication()
        configureWindow()
    }

    @MainActor
    private func configureApplication() {
        let application = NSApplication.shared
        application.setActivationPolicy(.regular)
        application.mainMenu = makeMainMenu()
    }

    @MainActor
    private func configureWindow() {
        let contentSize = NSSize(
            width: CGFloat(gameSettings.resolution.width),
            height: CGFloat(gameSettings.resolution.height)
        )
        let contentRect = NSRect(origin: .zero, size: contentSize)
        let view = GameView(
            frame: contentRect,
            device: device
        )
        var styleMask: NSWindow.StyleMask = [
            .titled,
            .closable,
            .miniaturizable
        ]
        if gameSettings.isResizable {
            styleMask.insert(.resizable)
        }

        let window = NSWindow(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        view.delegate = self
        view.preferredFramesPerSecond = gameSettings.preferredFps

        platform = MetalPlatform(view: view, renderSettings: renderSettings)

        window.title = gameSettings.title
        window.contentView = view
        window.delegate = self

        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)

        self.window = window
        self.gameView = view

        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @MainActor
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

}

extension Runtime: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let platform else { return }

        do {
            guard let drawable = platform.drawable() else { return }

            frame.reset()
            try game.render(
                on: platform,
                output: RenderTarget(texture: drawable.texture),
                frame: frame
            )

            try platform.present(frame, to: consume drawable)
        } catch {
            fatalError("Game rendering failed: \(error)")
        }
    }
}

extension Runtime: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApplication.shared.terminate(nil)
    }
}

@preconcurrency import AppKit
@preconcurrency import MetalKit
import PixlPlatform

final class Runtime: NSObject {
    private let device: MTLDevice
    private let frame: Frame
    private let gameSettings: GameSettings
    private let renderSettings: RenderSettings
    private let audioSettings: AudioSettings
    private let assetPath: String?
    private let assetSourcePath: String?
    private let makeGame: (any Platform) throws -> any PlatformGame
    private var game: (any PlatformGame)?
    private var platform: MetalPlatform?
    private var window: NSWindow?
    private var gameView: GameView?
    private var gamepadAdapter: MetalGamepads?

    init(
        gameSettings: GameSettings,
        renderSettings: RenderSettings,
        audioSettings: AudioSettings,
        assetPath: String?,
        assetSourcePath: String?,
        makeGame: @escaping (any Platform) throws -> any PlatformGame
    ) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not available")
        }

        self.device = device
        frame = Frame(
            passCapacity: renderSettings.framePassCapacity,
            commandCapacity: renderSettings.frameCommandCapacity,
            byteCapacity: renderSettings.frameByteCapacity
        )
        self.gameSettings = gameSettings
        self.renderSettings = renderSettings
        self.audioSettings = audioSettings
        self.assetPath = assetPath
        self.assetSourcePath = assetSourcePath
        self.makeGame = makeGame
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
        application.delegate = self
        application.setActivationPolicy(.regular)
        NSWindow.allowsAutomaticWindowTabbing = false
        application.mainMenu = makeMainMenu()
    }

    @MainActor
    private func configureWindow() {
        let contentSize = NSSize(
            width: CGFloat(gameSettings.resolution.x),
            height: CGFloat(gameSettings.resolution.y)
        )
        let contentRect = NSRect(origin: .zero, size: contentSize)
        let view = GameView(
            frame: contentRect,
            device: device,
            drawableFormat: renderSettings.drawableFormat
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
        window.tabbingMode = .disallowed
        window.contentView = view
        window.acceptsMouseMovedEvents = true
        NSEvent.isMouseCoalescingEnabled = false

        view.delegate = self
        view.preferredFramesPerSecond = gameSettings.preferredFps

        platform = MetalPlatform(
            view: view,
            renderSettings: renderSettings,
            audioSettings: audioSettings,
            assetPath: assetPath,
            assetSourcePath: assetSourcePath
        )
        view.keyboard = platform?.keyboard
        view.mouse = platform?.mouse
        gamepadAdapter = MetalGamepads(gamepads: platform!.gamepads)

        do {
            game = try makeGame(platform!)
        } catch {
            fatalError("Game initialization failed: \(error)")
        }

        window.title = gameSettings.title
        window.delegate = self

        self.window = window
        self.gameView = view
        updatePhase()

        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        platform?.keyboard.focus(true)

        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @MainActor
    private func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()
        let applicationMenuItem = NSMenuItem(title: "Pixl", action: nil, keyEquivalent: "")
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

        let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(
            withTitle: "Close Window",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        let viewMenuItem = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(
            withTitle: "Enter Full Screen",
            action: #selector(NSWindow.toggleFullScreen(_:)),
            keyEquivalent: "f"
        ).keyEquivalentModifierMask = [.control, .command]
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        let windowMenuItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(
            withTitle: "Minimize",
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        )
        windowMenu.addItem(
            withTitle: "Zoom",
            action: #selector(NSWindow.performZoom(_:)),
            keyEquivalent: ""
        )
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(
            withTitle: "Bring All to Front",
            action: #selector(NSApplication.arrangeInFront(_:)),
            keyEquivalent: ""
        )
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApplication.shared.windowsMenu = windowMenu

        return mainMenu
    }

    @MainActor
    private func updatePhase() {
        game?.didEnter(currentPhase)
    }

    @MainActor
    private var currentPhase: GamePhase {
        if NSApplication.shared.isHidden || window?.isMiniaturized == true {
            return .background
        }
        return NSApplication.shared.isActive ? .active : .inactive
    }

}

extension Runtime: NSApplicationDelegate {
    func applicationDidBecomeActive(_ notification: Notification) {
        updatePhase()
    }

    func applicationWillResignActive(_ notification: Notification) {
        if NSApplication.shared.isHidden || window?.isMiniaturized == true {
            game?.didEnter(.background)
        } else {
            game?.didEnter(.inactive)
        }
    }

    func applicationDidHide(_ notification: Notification) {
        game?.didEnter(.background)
    }

    func applicationDidUnhide(_ notification: Notification) {
        updatePhase()
    }
}

extension Runtime: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let platform, let game else { return }

        do {
            gamepadAdapter?.poll()
            platform.keyboard.publishPendingEvents()
            platform.mouse.publishPendingEvents()
            platform.gamepads.publishPendingEvents()
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
    func windowDidChangeBackingProperties(_ notification: Notification) {
        platform?.updateDisplayScale()
    }

    func windowWillClose(_ notification: Notification) {
        NSApplication.shared.terminate(nil)
    }

    func windowDidMiniaturize(_ notification: Notification) {
        platform?.keyboard.focus(false)
        platform?.mouse.focus(false, timestamp: ProcessInfo.processInfo.systemUptime)
        game?.didEnter(.background)
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        platform?.keyboard.focus(true)
        platform?.mouse.focus(true)
        updatePhase()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        platform?.keyboard.focus(true)
        platform?.mouse.focus(true)
        window?.makeFirstResponder(gameView)
    }

    func windowDidResignKey(_ notification: Notification) {
        platform?.keyboard.focus(false)
        platform?.mouse.focus(false, timestamp: ProcessInfo.processInfo.systemUptime)
    }
}

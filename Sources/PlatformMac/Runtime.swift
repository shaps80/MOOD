@preconcurrency import AppKit
@preconcurrency import MetalKit
import GameCore
import QuartzCore
import Swift

@MainActor
final class Runtime: NSObject {
    private var game: Game

    private let assetResolver = AssetResolver()
    private let keyboardInput = KeyboardInput()
    private let gamepadInput = GamepadInput()
    private let device: MTLDevice
    private let renderer: Renderer
    private let audio: Audio

    private var window: NSWindow?
    private var gameView: GameView?
    private var lastFrameTime: CFTimeInterval?
    private var accumulatedTime = 0.0

    init(game: Game) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not available")
        }

        self.game = game
        self.device = device
        self.renderer = Renderer(
            device: device,
            pixelFormat: .bgra8Unorm,
            assetResolver: assetResolver
        )
        self.audio = Audio(assetResolver: assetResolver)

        super.init()
    }

    var fixedTimeStep: Double {
        guard game.preferredFps > 0 else {
            return 1.0 / 60.0
        }

        return 1.0 / game.preferredFps
    }

    func start() {
        configureApplication()
        configureWindow()
        renderer.loadSpriteTextures(game.spriteAssets)
        audio.loadSoundBuffers(game.soundAssets)
    }

    private func configureApplication() {
        let application = NSApplication.shared

        application.setActivationPolicy(.regular)
        application.mainMenu = makeMainMenu()
    }

    private func configureWindow() {
        let contentSize = NSSize(
            width: CGFloat(game.size.x),
            height: CGFloat(game.size.y)
        )
        let contentRect = NSRect(origin: .zero, size: contentSize)
        let view = GameView(
            frame: contentRect,
            device: device,
            keyboardInput: keyboardInput
        )
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        view.delegate = self
        view.preferredFramesPerSecond = max(1, Int(game.preferredFps.rounded()))

        window.title = "MOOD"
        window.contentView = view
        window.contentAspectRatio = contentSize
        window.contentMinSize = NSSize(width: 320, height: 180)
        window.delegate = self
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
            title: "Quit MOOD",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        quitItem.target = NSApplication.shared
        applicationMenu.addItem(quitItem)
        applicationMenuItem.submenu = applicationMenu
        mainMenu.addItem(applicationMenuItem)

        return mainMenu
    }

    private var inputState: Input {
        keyboardInput.state
            .combined(with: gamepadInput.state)
    }

    private func renderFrame() {
        let now = CACurrentMediaTime()
        let rawDeltaSeconds = lastFrameTime.map {
            now - $0
        } ?? fixedTimeStep
        lastFrameTime = now

        accumulatedTime += max(rawDeltaSeconds, 0)

        while accumulatedTime >= fixedTimeStep {
            game.update(delta: fixedTimeStep, input: inputState)
            accumulatedTime -= fixedTimeStep
        }

        audio.playSounds(game.drainSounds())

        guard let gameView else { return }
        renderer.draw(game: game, in: gameView)
    }
}

extension Runtime: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        renderFrame()
    }
}

extension Runtime: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        keyboardInput.reset()
    }

    func windowWillClose(_ notification: Notification) {
        NSApplication.shared.terminate(nil)
    }
}

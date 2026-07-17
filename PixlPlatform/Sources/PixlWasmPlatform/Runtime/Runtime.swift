import JavaScriptKit
import PixlPlatform

final class Runtime {
    private let frame: Frame
    private let gameSettings: GameSettings
    private let renderSettings: RenderSettings
    private let audioSettings: AudioSettings
    private let makeGame: (any Platform) throws -> any PlatformGame
    private var platform: WasmPlatform?
    private var game: (any PlatformGame)?
    private var animationFrame: JSClosure?
    private var adapterReady: JSClosure?
    private var deviceReady: JSClosure?
    private var lifecycleChanged: JSClosure?
    private var keyboardAdapter: WasmKeyboard?
    private var lastPresentationMilliseconds: Double?

    deinit {
        removeLifecycleListeners()
    }

    init(gameSettings: GameSettings, renderSettings: RenderSettings, audioSettings: AudioSettings, makeGame: @escaping (any Platform) throws -> any PlatformGame) {
        frame = Frame(
            passCapacity: renderSettings.framePassCapacity,
            commandCapacity: renderSettings.frameCommandCapacity,
            byteCapacity: renderSettings.frameByteCapacity
        )
        self.gameSettings = gameSettings; self.renderSettings = renderSettings; self.audioSettings = audioSettings; self.makeGame = makeGame
    }

    func start() {
        guard let gpu = JSObject.global.navigator.gpu.object else { fatalError("WebGPU is not available") }
        let adapterPromise = JSPromise(unsafelyWrapping: gpu.requestAdapter!().object!)
        adapterReady = JSClosure { [unowned self] arguments in
            guard let adapter = arguments.first?.object else { fatalError("WebGPU adapter creation failed") }
            let devicePromise = JSPromise(unsafelyWrapping: adapter.requestDevice!().object!)
            self.deviceReady = JSClosure { [unowned self] arguments in
                guard let device = arguments.first?.object else { fatalError("WebGPU device creation failed") }
                self.configure(device: device, gpu: gpu)
                return .undefined
            }
            _ = devicePromise.jsObject.then!(self.deviceReady!)
            return .undefined
        }
        _ = adapterPromise.jsObject.then!(adapterReady!)
    }

    private func configure(device: JSObject, gpu: JSObject) {
        let document = JSObject.global.document
        document.title = .string(gameSettings.title)
        let canvas = document.createElement("canvas").object!
        let canvasStyle = canvas.style.object!
        canvasStyle.width = .string("100vw"); canvasStyle.height = .string("100vh"); canvasStyle.display = .string("block")
        let body = document.body.object!; let bodyStyle = body.style.object!
        bodyStyle.margin = .string("0"); bodyStyle.overflow = .string("hidden"); _ = body.appendChild!(canvas)
        guard let context = canvas.getContext!("webgpu").object else { fatalError("WebGPU canvas context creation failed") }
        let preferred = gpu.getPreferredCanvasFormat!().string ?? "bgra8unorm"
        let format: PixelFormat = preferred == "rgba8unorm" ? .rgba8Unorm : .bgra8Unorm
        guard format == renderSettings.drawableFormat else { fatalError("WebGPU preferred canvas format does not match RenderSettings.drawableFormat") }
        let configuration = object(); configuration["device"] = .object(device); configuration["format"] = .string(preferred); configuration["alphaMode"] = .string("opaque"); _ = context.configure!(configuration)
        let platform = WasmPlatform(device: device, context: context, canvas: canvas, format: format, renderSettings: renderSettings, audioSettings: audioSettings)
        keyboardAdapter = WasmKeyboard(keyboard: platform.keyboard, canvas: canvas)
        do { game = try makeGame(platform) } catch { fatalError("Game initialization failed: \(error)") }
        self.platform = platform
        installLifecycleListeners()
        updatePhase()
        animationFrame = JSClosure { [unowned self] arguments in
            self.presentationFrame(milliseconds: arguments.first?.number ?? 0)
            return .undefined
        }
        _ = JSObject.global.requestAnimationFrame!(animationFrame!)
    }

    private func presentationFrame(milliseconds: Double) {
        defer { _ = JSObject.global.requestAnimationFrame!(animationFrame!) }
        let minimumDelta = 1_000 / Double(gameSettings.preferredFps)
        if let lastPresentationMilliseconds,
           milliseconds - lastPresentationMilliseconds < minimumDelta * 0.95 {
            return
        }
        lastPresentationMilliseconds = milliseconds
        draw()
    }

    private func draw() {
        guard let platform, let game, let drawable = platform.drawable() else { return }
        do {
            platform.keyboard.publishPendingEvents()
            frame.reset()
            try game.render(on: platform, output: RenderTarget(texture: drawable.texture), frame: frame)
            try platform.present(frame, to: consume drawable)
        } catch { fatalError("Game rendering failed: \(error)") }
    }

    private func installLifecycleListeners() {
        let closure = JSClosure { [weak self] _ in
            self?.updatePhase()
            return .undefined
        }
        lifecycleChanged = closure

        let global = JSObject.global
        _ = global.document.addEventListener("visibilitychange", closure)
        _ = global.window.addEventListener("focus", closure)
        _ = global.window.addEventListener("blur", closure)
    }

    private func removeLifecycleListeners() {
        guard let lifecycleChanged else { return }
        let global = JSObject.global
        _ = global.document.removeEventListener(
            "visibilitychange",
            lifecycleChanged
        )
        _ = global.window.removeEventListener("focus", lifecycleChanged)
        _ = global.window.removeEventListener("blur", lifecycleChanged)
        self.lifecycleChanged = nil
    }

    private func updatePhase() {
        game?.didEnter(currentPhase)
    }

    private var currentPhase: GamePhase {
        let document = JSObject.global.document
        if document.visibilityState.string == "hidden" {
            return .background
        }
        return document.hasFocus().boolean == false ? .inactive : .active
    }
}

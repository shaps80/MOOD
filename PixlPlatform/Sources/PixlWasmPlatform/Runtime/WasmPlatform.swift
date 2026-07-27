import JavaScriptKit
import PixlPlatform

final class WasmPlatform: Platform {
    private let wasmDevice: WasmDevice
    private let wasmAudio: AudioEngine<WasmAudioBackend>
    private let queue: WasmQueue
    private let context: JSObject
    private let canvas: JSObject
    private let format: PixelFormat
    private let drawables: ResourcePool<JSObject>

    var device: any Device { wasmDevice }
    var audioDevice: any AudioDevice { wasmAudio }
    var displayScale: Float {
        let value = Float(JSObject.global.window.devicePixelRatio.number ?? 1)
        return value.isFinite && value > 0 ? value : 1
    }
    let keyboard = Keyboard()
    let mouse = Mouse()
    let gamepads = Gamepads()
    let assetSource: (any AssetSource)?

    init(device: JSObject, context: JSObject, canvas: JSObject, format: PixelFormat, renderSettings: RenderSettings, audioSettings: AudioSettings) {
        wasmDevice = WasmDevice(device: device, settings: renderSettings)
        guard let audioBackend = WasmAudioBackend() else {
            fatalError("Web Audio is not available")
        }
        wasmAudio = AudioEngine(
            backend: audioBackend,
            settings: audioSettings
        )
        queue = wasmDevice.makeWasmQueue()
        self.context = context; self.canvas = canvas; self.format = format
        drawables = ResourcePool(capacity: renderSettings.drawableCapacity)
        assetSource = WasmAssetSource()
    }

    func resize() {
        let ratio = Double(displayScale)
        let width = max(1, Int((canvas.clientWidth.number ?? 1) * ratio))
        let height = max(1, Int((canvas.clientHeight.number ?? 1) * ratio))
        if Int(canvas.width.number ?? 0) != width { canvas.width = .number(Double(width)) }
        if Int(canvas.height.number ?? 0) != height { canvas.height = .number(Double(height)) }
    }

    func drawable() -> Drawable? {
        resize()
        guard let texture = context.getCurrentTexture!().object,
              let textureID = wasmDevice.textures.insert(texture),
              let drawableID = drawables.insert(texture) else { return nil }
        let descriptor = TextureDescriptor(size: .init(width: Int(canvas.width.number!), height: Int(canvas.height.number!)), format: format, usage: [.renderAttachment])
        return Drawable(texture: Texture(id: textureID, descriptor: descriptor), id: drawableID)
    }

    func present(_ frame: borrowing Frame, to drawable: consuming Drawable) throws(PlatformError) {
        defer { release(drawable.id, drawable.texture.id) }
        do { try queue.submit(frame) } catch { throw .queue(error) }
    }

    func discard(_ drawable: consuming Drawable) { release(drawable.id, drawable.texture.id) }
    private func release(_ drawable: ResourceID, _ texture: ResourceID) { _ = drawables.remove(drawable); _ = wasmDevice.textures.remove(texture) }
}

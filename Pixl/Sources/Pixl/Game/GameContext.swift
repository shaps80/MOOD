import PixlFoundation
import PixlPlatform

/// Stable runtime services and controls supplied throughout the game lifecycle.
public final class GameContext {
    public let platform: any Platform
    public let drawableFormat: PixelFormat
    public let audio: Audio
    public let assets: Assets
    public let keyboard: Keyboard
    public let gamepads: Gamepads
    public let inputs: Input.Map
    public let renderQueue: RenderQueue
    let spriteRenderResources: SpriteRenderResources
    private var renderMetrics = RenderQueue.Metrics()

    /// Nonnegative simulation-time multiplier. Zero pauses scaled simulation.
    public var timeScale: Double = 1 {
        didSet {
            precondition(
                timeScale.isFinite && timeScale >= 0,
                "Time scale must be finite and nonnegative"
            )
        }
    }

    init(
        platform: any Platform,
        format: PixelFormat,
        renderQueueSettings: RenderQueue.Settings
    ) {
        self.platform = platform
        self.drawableFormat = format
        keyboard = platform.keyboard
        gamepads = platform.gamepads
        inputs = Input.Map(keyboard: keyboard, gamepads: gamepads)
        audio = Audio(device: platform.audioDevice)
        let assets = Assets(
            device: platform.device,
            audioDevice: platform.audioDevice,
            source: platform.assetSource
        )
        self.assets = assets
        renderQueue = RenderQueue(settings: renderQueueSettings)
        spriteRenderResources = SpriteRenderResources(
            device: platform.device,
            capacity: renderQueueSettings.capacity,
            textureForID: { assets.texture(for: $0) }
        )
    }

    public func pause(_ paused: Bool) {
        timeScale = paused ? 0 : 1
    }

    func record(_ metrics: RenderQueue.Metrics) {
        renderMetrics.loweringSeconds += metrics.loweringSeconds
        renderMetrics.cullingSeconds += metrics.cullingSeconds
        renderMetrics.layerBinningSeconds += metrics.layerBinningSeconds
        renderMetrics.orderingSeconds += metrics.orderingSeconds
        renderMetrics.batchingSeconds += metrics.batchingSeconds
        renderMetrics.instancesSeconds += metrics.instancesSeconds
    }

    func consumeRenderMetrics() -> RenderQueue.Metrics {
        defer { renderMetrics = .init() }
        return renderMetrics
    }
}

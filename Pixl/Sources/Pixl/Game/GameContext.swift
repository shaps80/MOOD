import PixlFoundation
import PixlPlatform

/// Stable runtime services and controls supplied throughout the game lifecycle.
public final class GameContext {
    /// Lowest-level platform services for deliberate direct use.
    public let platform: any Platform
    /// Pixel format of platform presentation targets.
    public let drawableFormat: PixelFormat
    /// Game-facing audio access.
    public let audio: Audio
    /// Context-owned asset loader and cache.
    public let assets: Assets
    /// Current physical keyboard state.
    public let keyboard: Keyboard
    /// Currently connected game controllers.
    public let gamepads: Gamepads
    /// Game-defined semantic input map.
    public let inputs: Input.Map
    /// Default retained queue for render submissions.
    public let renderQueue: RenderQueue
    let spriteRenderResources: SpriteRenderResources
    let spriteRenderWorkspace: SpriteRenderWorkspace
    private var spriteRenderWorkspaces: [ObjectIdentifier: SpriteRenderWorkspace] = [:]
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
        let spriteRenderResources = SpriteRenderResources(
            device: platform.device,
            textures: assets.textureResources!
        )
        self.spriteRenderResources = spriteRenderResources
        spriteRenderWorkspace = spriteRenderResources.makeWorkspace(for: renderQueue)
    }

    /// Pauses or resumes scaled simulation using ``timeScale``.
    /// - Parameter paused: `true` sets time scale to `0`; `false` restores it to `1`.
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

    func workspace(for queue: RenderQueue) -> SpriteRenderWorkspace {
        if queue === renderQueue { return spriteRenderWorkspace }
        let identity = ObjectIdentifier(queue)
        if let workspace = spriteRenderWorkspaces[identity] {
            return workspace
        }
        let workspace = spriteRenderResources.makeWorkspace(for: queue)
        spriteRenderWorkspaces[identity] = workspace
        return workspace
    }
}

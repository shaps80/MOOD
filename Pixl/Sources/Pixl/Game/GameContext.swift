import PixlFoundation
import PixlGraphics
import PixlPlatform
import PixlUI

/// Stable runtime services and controls supplied throughout the game lifecycle.
public final class GameContext {
    /// Lowest-level platform services for deliberate direct use.
    public let platform: any Platform
    /// Pixel format of platform presentation targets.
    public let drawableFormat: PixelFormat
    /// Current number of presentation pixels per logical screen-space point.
    public var displayScale: Float { platform.displayScale }
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
    let sceneRenderQueue: RenderQueue
    let spriteRenderResources: SpriteRenderResources
    let spriteRenderWorkspace: SpriteRenderWorkspace
    let sceneRenderWorkspace: SpriteRenderWorkspace
    private var spriteRenderWorkspaces: [ObjectIdentifier: SpriteRenderWorkspace] = [:]
    private var sceneCompilations: [ObjectIdentifier: SceneCompilation] = [:]
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
        sceneRenderQueue = RenderQueue(settings: renderQueueSettings)
        let spriteRenderResources = SpriteRenderResources(
            device: platform.device,
            textures: assets.textureResources!
        )
        self.spriteRenderResources = spriteRenderResources
        spriteRenderWorkspace = spriteRenderResources.makeWorkspace(for: renderQueue)
        sceneRenderWorkspace = spriteRenderResources.makeWorkspace(for: sceneRenderQueue)
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
        if queue === sceneRenderQueue { return sceneRenderWorkspace }
        let identity = ObjectIdentifier(queue)
        if let workspace = spriteRenderWorkspaces[identity] {
            return workspace
        }
        let workspace = spriteRenderResources.makeWorkspace(for: queue)
        spriteRenderWorkspaces[identity] = workspace
        return workspace
    }

    func compilation<Content: View>(
        for scene: Scene<Content>,
        size: Size,
        displayScale: Float
    ) -> SceneCompilation {
        let identity = ObjectIdentifier(scene)
        if let compilation = sceneCompilations[identity],
           compilation.matches(
               scene: scene,
               size: size,
               displayScale: displayScale
           ) {
            return compilation
        }
        let compilation = SceneCompilation(
            scene: scene,
            size: size,
            displayScale: displayScale
        )
        sceneCompilations[identity] = compilation
        return compilation
    }
}

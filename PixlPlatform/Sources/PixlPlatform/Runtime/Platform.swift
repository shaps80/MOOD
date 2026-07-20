import Swift

/// Runtime callbacks required by a concrete platform adapter.
public protocol PlatformGame {
    /// Startup window and presentation preferences.
    static var gameSettings: GameSettings { get }
    /// Fixed capacities and drawable format used for frame recording.
    static var renderSettings: RenderSettings { get }
    /// Fixed capacities used by the audio device.
    static var audioSettings: AudioSettings { get }
    /// Optional packaged asset path used by the adapter.
    static var assetPath: String? { get }
    /// Optional development source path used for live asset access.
    static var assetSourcePath: String? { get }

    /// Creates the platform-facing game after platform services exist.
    /// - Parameter platform: Concrete runtime platform.
    /// - Throws: Any error encountered while preparing the game.
    init(platform: any Platform) throws

    /// Reports one coarse lifecycle transition.
    /// - Parameter phase: Newly entered platform phase.
    func didEnter(_ phase: GamePhase)

    /// Records one presentation frame.
    /// - Parameters:
    ///   - platform: Runtime supplying GPU and presentation capabilities.
    ///   - output: Render target for this presentation.
    ///   - frame: Reusable frame recording storage.
    /// - Throws: Any error encountered while recording the frame.
    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame
    ) throws
}

public extension PlatformGame {
    /// No packaged asset path by default.
    static var assetPath: String? { nil }
    /// No development asset-source path by default.
    static var assetSourcePath: String? { nil }
}

/// Lowest-level portable runtime seam over presentation and platform services.
public protocol Platform: AnyObject {
    /// Logical GPU device.
    var device: any Device { get }
    /// Platform audio device.
    var audioDevice: any AudioDevice { get }
    /// Optional source of asset bytes and change notifications.
    var assetSource: (any AssetSource)? { get }
    /// Current physical keyboard state.
    var keyboard: Keyboard { get }
    /// Connected game controllers.
    var gamepads: Gamepads { get }

    /// Acquires the next frame-scoped presentation surface when available.
    /// - Returns: A drawable to render and present, or `nil` when presentation is unavailable.
    func drawable() -> Drawable?

    /// Submits a recorded frame and consumes its presentation surface.
    /// - Parameters:
    ///   - frame: Frame containing commands targeting `drawable`.
    ///   - drawable: Presentation surface previously acquired from this platform.
    /// - Throws: ``PlatformError`` when the drawable is invalid or submission fails.
    func present(
        _ frame: borrowing Frame,
        to drawable: consuming Drawable
    ) throws(PlatformError)

    /// Returns an acquired drawable without presenting it.
    /// - Parameter drawable: Unpresented surface previously acquired from this platform.
    func discard(_ drawable: consuming Drawable)
}

public extension Platform {
    /// No asset source by default.
    var assetSource: (any AssetSource)? { nil }
}

/// A platform presentation failure.
public enum PlatformError: Error, Hashable, Sendable {
    /// A drawable is stale, already consumed, or does not belong to this platform.
    case invalidDrawable
    /// Frame submission failed on the platform's GPU queue.
    case queue(QueueError)
}

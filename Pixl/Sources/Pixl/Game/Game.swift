import PixlPlatform
import PixlFoundation

/// Main game value driven by Pixl's lifecycle, update, and render loop.
public protocol Game {
    /// Startup window and presentation preferences.
    static var gameSettings: GameSettings { get }
    /// GPU format and fixed-capacity preferences.
    static var renderSettings: RenderSettings { get }
    /// Audio resource capacities.
    static var audioSettings: AudioSettings { get }
    /// Fixed and variable update timing policy.
    static var loopSettings: LoopSettings { get }
    /// Packaged asset location.
    static var assetSettings: AssetSettings { get }
    /// Default render-submission and view capacities.
    static var renderQueueSettings: RenderQueue.Settings { get }

    /// Creates game state after stable runtime services are available.
    /// - Parameter context: Stable services retained for the game's lifetime.
    /// - Throws: Any error encountered while preparing initial game state or resources.
    init(context: GameContext) throws

    /// Invoked when the platform enters a different lifecycle phase.
    /// - Parameters:
    ///   - phase: Newly entered coarse lifecycle phase.
    ///   - context: Stable runtime services and controls.
    mutating func didEnter(_ phase: GamePhase, context: GameContext)

    /// Invoked serially for each fixed simulation tick.
    /// - Parameters:
    ///   - time: Fixed simulation timing.
    ///   - context: Stable runtime services and controls.
    mutating func fixedUpdate(
        _ time: FixedTime,
        context: GameContext
    )

    /// Invoked serially for each presentation update.
    /// - Parameters:
    ///   - time: Scaled and unscaled presentation timing.
    ///   - context: Stable runtime services and controls.
    mutating func update(
        _ time: UpdateTime,
        context: GameContext
    )

    /// Invoked once per presentation after the update callback.
    /// - Parameters:
    ///   - platform: Lowest-level platform capabilities for deliberate direct rendering.
    ///   - output: Presentation render target.
    ///   - frame: Reusable storage into which render commands are recorded.
    ///   - time: Render interpolation and prior-frame metrics.
    ///   - context: Stable runtime services and default render queue.
    /// - Throws: Any error encountered while resolving resources or recording commands.
    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame,
        time: RenderTime,
        context: GameContext
    ) throws

    /// Starts the game using the concrete adapter available to this build.
    @MainActor
    static func main()
}

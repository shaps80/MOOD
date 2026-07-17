import PixlConcurrency
import PixlPlatform

public protocol Game {
    static var gameSettings: GameSettings { get }
    static var renderSettings: RenderSettings { get }
    static var audioSettings: AudioSettings { get }
    static var loopSettings: LoopSettings { get }
    static var assetSettings: AssetSettings { get }

    /// Multiplier applied to simulation time.
    ///
    /// Define a mutable stored property in the game to change it at runtime.
    /// `0` pauses simulation time and fixed updates while variable updates and
    /// rendering continue. Audio time is independent.
    var timeScale: Double { get }

    init(context: GameContext) throws

    /// Invoked when the platform enters a different lifecycle phase.
    mutating func didEnter(_ phase: GamePhase, context: GameContext)

    /// Invoked serially for each fixed simulation tick.
    mutating func fixedUpdate(_ time: FixedTime, lanes: Lanes)

    /// Invoked serially for each presentation update.
    mutating func update(_ time: UpdateTime, lanes: Lanes)

    /// Invoked on the leader lane because `Frame` recording is not yet
    /// lane-partitioned.
    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame,
        time: RenderTime
    ) throws

    @MainActor
    static func main()
}

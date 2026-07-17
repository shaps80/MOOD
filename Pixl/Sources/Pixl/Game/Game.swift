import PixlPlatform

public protocol Game {
    static var gameSettings: GameSettings { get }
    static var renderSettings: RenderSettings { get }
    static var audioSettings: AudioSettings { get }
    static var loopSettings: LoopSettings { get }
    static var assetSettings: AssetSettings { get }

    init(context: GameContext) throws

    /// Invoked when the platform enters a different lifecycle phase.
    mutating func didEnter(_ phase: GamePhase, context: GameContext)

    /// Invoked serially for each fixed simulation tick.
    mutating func fixedUpdate(
        _ time: FixedTime,
        context: GameContext
    )

    /// Invoked serially for each presentation update.
    mutating func update(
        _ time: UpdateTime,
        context: GameContext
    )

    /// Invoked once per presentation after the update callback.
    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame,
        time: RenderTime,
        context: GameContext
    ) throws

    @MainActor
    static func main()
}

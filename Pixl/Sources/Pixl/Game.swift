import PixlConcurrency
import PixlPlatform

/// A game shell whose mutable simulation data is owned by lane-partitioned
/// reference storage rather than stored directly in the game value.
public protocol Game {
    static var defaultShaders: Shader { get }
    static var gameSettings: GameSettings { get }
    static var renderSettings: RenderSettings { get }
    static var loopSettings: LoopSettings { get }

    init(platform: any Platform) throws

    /// Invoked concurrently once on every lane for each fixed simulation tick.
    func fixedUpdate(_ time: FixedTime, lane: Lane)

    /// Invoked concurrently once on every lane for each presentation update.
    func update(_ time: UpdateTime, lane: Lane)

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

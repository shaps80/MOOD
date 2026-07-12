import PixlConcurrency
import PixlPlatform

public protocol Game {
    static var defaultShaders: Shader { get }
    static var gameSettings: GameSettings { get }
    static var renderSettings: RenderSettings { get }
    static var loopSettings: LoopSettings { get }

    init(platform: any Platform) throws

    /// Invoked serially for each fixed simulation tick.
    func fixedUpdate(_ time: FixedTime, lanes: Lanes)

    /// Invoked serially for each presentation update.
    func update(_ time: UpdateTime, lanes: Lanes)

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

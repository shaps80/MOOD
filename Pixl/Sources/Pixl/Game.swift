import PixlPlatform

public protocol Game {
    static var defaultShaders: Shader { get }
    static var gameSettings: GameSettings { get }
    static var renderSettings: RenderSettings { get }
    static var loopSettings: LoopSettings { get }

    init(platform: any Platform) throws

    mutating func fixedUpdate(_ time: FixedTime)
    mutating func update(_ time: UpdateTime)

    mutating func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame,
        time: RenderTime
    ) throws

    @MainActor
    static func main()
}

@_exported import PixlPlatform
@_exported import PixlGraphics

#if canImport(PixlMetalPlatform)
import PixlMetalPlatform
#endif

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

public extension Game {
    static var defaultShaders: Shader {
        ShaderCatalogue.default
    }

    static var renderSettings: RenderSettings {
        .default
    }

    static var loopSettings: LoopSettings {
        .default
    }

    mutating func fixedUpdate(_ time: FixedTime) {}

    mutating func update(_ time: UpdateTime) { }

    @MainActor
    static func main() {
#if canImport(PixlMetalPlatform)
        PixlMetalPlatform.run(GameRuntime<Self>.self)
#else
        fatalError("No Pixl platform is available for this build")
#endif
    }
}

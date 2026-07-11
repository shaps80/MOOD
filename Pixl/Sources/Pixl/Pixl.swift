@_exported import PixlPlatform

#if canImport(PixlMetalPlatform)
import PixlMetalPlatform
#endif

public protocol Game: PlatformGame {
    init()
    static var renderSettings: RenderSettings { get }
    @MainActor
    static func main()
}

extension Game {
    public static var renderSettings: RenderSettings { .default }

    @MainActor
    public static func main() {
#if canImport(PixlMetalPlatform)
        PixlMetalPlatform.run(Self(), renderSettings: Self.renderSettings)
#else
        fatalError("No Pixl platform is available for this build")
#endif
    }
}

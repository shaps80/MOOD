@_exported import PixlPlatform
import PixlGraphics

#if canImport(PixlMetalPlatform)
import PixlMetalPlatform
#endif

public protocol Game: PlatformGame {
    @MainActor
    static func main()
}

public extension Game {
    static public var defaultShaders: Shader {
        ShaderCatalogue.default
    }
}

extension Game {
    public static var renderSettings: RenderSettings { .default }

    @MainActor
    public static func main() {
#if canImport(PixlMetalPlatform)
        PixlMetalPlatform.run(Self.self)
#else
        fatalError("No Pixl platform is available for this build")
#endif
    }
}

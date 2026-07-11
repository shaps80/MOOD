@_exported import PixlPlatform

#if canImport(PixlMetalPlatform)
import PixlMetalPlatform
#endif

public protocol Game: PlatformGame {
    init()
    @MainActor
    static func main()
}

extension Game {
    @MainActor
    public static func main() {
#if canImport(PixlMetalPlatform)
        PixlMetalPlatform.run(Self())
#else
        fatalError("No Pixl platform is available for this build")
#endif
    }
}

@_exported import PixlPlatform

#if canImport(PixlMetalPlatform)
import PixlMetalPlatform
#endif

public protocol Game: PlatformGame {
    init()
    static func main()
}

extension Game {
    public static func main() {
#if canImport(PixlMetalPlatform)
        PixlMetalPlatform.run(Self())
#else
        fatalError("No Pixl platform is available for this build")
#endif
    }
}

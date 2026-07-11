#if canImport(PixlMetalPlatform)
import PixlMetalPlatform
#endif

public enum Pixl {
    @MainActor
    public static func run() {
#if canImport(PixlMetalPlatform)
        PixlMetalPlatform.run()
#else
        fatalError("No Pixl platform is available for this build")
#endif
    }
}

#if os(WASI)
import PlatformWeb
#endif
#if os(macOS)
import PlatformMac
#endif

@main
struct MOOD {
#if os(macOS)
    @MainActor
    static func main() {
        PlatformMac.run()
    }
#else
    static func main() {
#if os(WASI)
        PlatformWeb.run()
#else
        print("This platform is not currently supported!")
#endif
    }
#endif
}

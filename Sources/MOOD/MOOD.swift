#if os(WASI)
import PlatformWeb
#endif

@main
struct MOOD {
    static func main() {
#if os(WASI)
        PlatformWeb.run()
#else
        print("This platform is not currently supported!")
#endif
    }
}

import Swift
import GameCore

public enum PlatformWeb {
    public static func run() {
        BrowserRuntime(game: Game()).start()
    }
}

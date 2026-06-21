import Swift
import GameCore

public enum PlatformWeb {
    public static func run() {
        Runtime(game: Game()).start()
    }
}

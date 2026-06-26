import Swift
import Pixl

public enum PlatformWeb {
    public static func run(game: Game) {
        Runtime(game: game).start()
    }
}

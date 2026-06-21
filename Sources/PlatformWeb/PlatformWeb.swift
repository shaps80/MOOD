import Swift
import GameCore

public enum PlatformWeb {
    public static func run(tickLimit: Int = 3) {
        var runtime = Runtime(game: Game())
        runtime.run(tickLimit: tickLimit)
    }
}

private struct Runtime {
    private var game: Game

    init(game: Game) {
        self.game = game
    }

    mutating func run(tickLimit: Int) {
        print("MOOD PlatformWeb starting")

        for _ in 0..<tickLimit {
            game.tick()
            print("MOOD tick \(game.tickCount)")
        }
    }
}

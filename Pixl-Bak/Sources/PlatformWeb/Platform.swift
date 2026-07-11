import Swift
import Pixl

public enum PlatformWeb {
    // Browser runtime is single-threaded and must outlive asynchronous GPU setup.
    nonisolated(unsafe) private static var runtime: Runtime?

    public static func run(game: Game) {
        let runtime = Runtime(game: game)
        self.runtime = runtime
        runtime.start()
    }
}

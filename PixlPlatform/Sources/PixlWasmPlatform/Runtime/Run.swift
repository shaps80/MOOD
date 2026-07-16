import PixlPlatform

nonisolated(unsafe) private var retainedRuntime: AnyObject?

public func run<Game: PlatformGame>(_ game: Game.Type) {
    let runtime = Runtime(gameSettings: Game.gameSettings, renderSettings: Game.renderSettings) { try Game(platform: $0) }
    retainedRuntime = runtime
    runtime.start()
}

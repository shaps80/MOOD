import Swift
import GameCore
import JavaScriptKit

public enum PlatformWeb {
    public static func run() {
        BrowserRuntime(game: Game()).start()
    }
}

private final class BrowserRuntime {
    private var game: Game
    private var animationFrameCallback: JSClosure?

    init(game: Game) {
        self.game = game
    }

    func start() {
        log("MOOD PlatformWeb starting")

        animationFrameCallback = JSClosure { _ in
            self.tick()
            return .undefined
        }

        requestNextFrame()
    }

    private func tick() {
        game.tick()

        if game.tickCount == 1 || game.tickCount.isMultiple(of: 60) {
            log("MOOD tick \(game.tickCount)")
        }

        requestNextFrame()
    }

    private func requestNextFrame() {
        guard let animationFrameCallback else { return }

        _ = JSObject.global.requestAnimationFrame!(animationFrameCallback)
    }

    private func log(_ message: String) {
        _ = JSObject.global.console.log(message)
    }
}

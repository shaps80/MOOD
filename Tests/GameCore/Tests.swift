import Testing
@testable import GameCore

@Suite("Game Core Tests")
struct GameCoreTests {
    func gameCoreAvailable() {
        _ = Game()
    }
}

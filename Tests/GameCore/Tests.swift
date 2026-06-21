import Testing
@testable import GameCore

@Test func gameCoreAvailable() {
    var game = Game()
    game.tick()
    #expect(game.tickCount == 1)
}

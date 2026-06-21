import Testing
@testable import GameCore

@Test func gameCoreAvailable() {
    var game = Game()
    game.tick()
    #expect(game.tickCount == 1)
}

@Test func clearColorRotatesEveryElapsedSecond() {
    var game = Game()

    game.tick(elapsedSeconds: 0)
    #expect(game.clearColor == Game.clearColors[0])

    game.tick(elapsedSeconds: 1)
    #expect(game.clearColor == Game.clearColors[1])

    game.tick(elapsedSeconds: 2)
    #expect(game.clearColor == Game.clearColors[2])

    game.tick(elapsedSeconds: 3)
    #expect(game.clearColor == Game.clearColors[3])

    game.tick(elapsedSeconds: 4)
    #expect(game.clearColor == Game.clearColors[0])
}

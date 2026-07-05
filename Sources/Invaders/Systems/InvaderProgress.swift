import Pixl

enum SpaceInvadersProgress {
    nonisolated(unsafe)
    private(set) static var bombCount = 0

    static func grantBombs(_ count: Int = 1) {
        bombCount += max(count, 0)
    }

    static func useBomb() -> Bool {
        guard bombCount > 0 else {
            return false
        }

        bombCount -= 1
        return true
    }

    static func resetBombs() {
        bombCount = 0
    }
}

struct InvaderProgress: GameSystem {
    private var initialInvaderCount: Int?
    private var awardedBombThresholds = 0
    private var didWin = false

    mutating func update(context: inout Game.SystemContext) {
        let invaderCount = context.ids(kind: Invader.self).count

        if initialInvaderCount == nil, invaderCount > 0 {
            initialInvaderCount = invaderCount
        }

        if initialInvaderCount != nil, invaderCount == 0, !didWin {
            didWin = true
            context.play(sound: .win)
            return
        }

        guard let initialInvaderCount,
              awardedBombThresholds < bombKillThresholdCount
        else {
            return
        }

        let killedCount = initialInvaderCount - invaderCount
        let requiredKills = requiredKillsForNextThreshold(
            initialInvaderCount: initialInvaderCount
        )

        guard killedCount >= requiredKills else {
            return
        }

        awardedBombThresholds += 1
        SpaceInvadersProgress.grantBombs()
        context.play(sound: .levelup)
    }

    private var bombKillThresholdCount: Int {
        2
    }

    private func requiredKillsForNextThreshold(
        initialInvaderCount: Int
    ) -> Int {
        switch awardedBombThresholds {
        case 0:
            max(initialInvaderCount / 3, 1)
        default:
            max(initialInvaderCount / 2, 1)
        }
    }
}

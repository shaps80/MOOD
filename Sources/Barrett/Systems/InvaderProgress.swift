import Pixl

enum SpaceInvadersProgress {
    nonisolated(unsafe)
    private(set) static var levelUpToken = 0

    static func grantLevelUp() {
        levelUpToken += 1
    }
}

struct InvaderProgress: GameSystem {
    private var initialInvaderCount: Int?
    private var didLevelUp = false

    mutating func update(context: inout Game.SystemContext) {
        let invaderCount = context.ids(kind: Invader.self).count

        if initialInvaderCount == nil, invaderCount > 0 {
            initialInvaderCount = invaderCount
        }

        guard let initialInvaderCount,
              !didLevelUp,
              invaderCount <= .init(initialInvaderCount / 3)
        else {
            return
        }

        didLevelUp = true
        SpaceInvadersProgress.grantLevelUp()
    }
}

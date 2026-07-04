import Pixl

struct InvaderWave: GameSystem {
    private var direction: Double = 1
    private let speed: Double = 52
    private let stepDown: Double = 16

    mutating func update(context: inout Game.SystemContext) {
        let invaders = context.ids(kind: Invader.self)

        guard let bounds = context.bounds(for: invaders) else {
            context.restart()
            return
        }

        var movement = Vec2(x: direction * speed * context.delta, y: 0)
        let proposed = bounds.translated(by: movement)

        if proposed.minX < GameConfig.playBounds.minX
            || proposed.maxX > GameConfig.playBounds.maxX {
            direction *= -1
            movement = Vec2(x: direction * speed * context.delta, y: stepDown)
        }

        context.move(invaders, by: movement)
    }
}


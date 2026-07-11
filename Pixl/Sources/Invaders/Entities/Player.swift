import Pixl

struct Player: Entity {
    private var horizontal = AxisController(
        maxSpeed: 1000,
        acceleration: 4000,
        deceleration: 4000
    )
    private var gun = Gun(roundsPerSecond: 25)
    private var wasBombPressed = false
    private var continuousFireDuration: Double = 0
    private var didPlayEmpty = false
    private let maxContinuousFireDuration: Double = 1

    private var recoilTime: Double = 0
    private var recoilDuration: Double = 0.05
    private var recoilDistance: Double = 4

    mutating func prepare(context: inout Game.PreparationContext, state: inout EntityState) {
        state.sprite = Sprite(
            material: .shape(
                RoundedRectangle(cornerRadius: 8),
                size: GameConfig.playerSize
            ),
            layer: .player,
            tint: .gray
        )
        state.colliders = [
            Collider(
                bounds: Rect(size: GameConfig.playerSize),
                layer: .player,
                mask: [.playerMovement, .invader],
                behaviour: .blocking
            )
        ]
    }

    mutating func onUpdate(context: inout Game.Context, state: inout EntityState) {
        gun.update(delta: context.delta)

        state.velocity = Vec2(
            x: horizontal.velocity(
                current: state.velocity.x,
                input: context.input.horizontal,
                delta: context.delta
            ),
            y: 0
        )

        updateRecoil(context: context, state: &state)

        firePrimaryWeapon(context: &context, state: &state)
        fireBomb(context: &context, state: state)
    }

    private mutating func firePrimaryWeapon(
        context: inout Game.Context,
        state: inout EntityState
    ) {
        guard context.input.jump else {
            continuousFireDuration = 0
            didPlayEmpty = false
            return
        }

        continuousFireDuration += context.delta

        guard continuousFireDuration < maxContinuousFireDuration else {
            if !didPlayEmpty {
                context.play(sound: .empty)
                didPlayEmpty = true
            }

            return
        }

        guard gun.fire() else {
            return
        }

        let bulletID = context.spawn(
            Bullet.self,
            at: Vec2(
                x: (GameConfig.playerSize.x - GameConfig.bulletSize.x) / 2,
                y: -GameConfig.bulletSize.y
            ),
            in: .entity(state.id)
        )

        context[bulletID]?.velocity.x = -state.velocity.x * 0.15
        context.play(sound: .laser)
        recoilTime = recoilDuration
        recoilDistance = 5
    }

    private mutating func fireBomb(
        context: inout Game.Context,
        state: EntityState
    ) {
        let bombPressed = context.input.vertical < -0.5

        defer {
            wasBombPressed = bombPressed
        }

        guard bombPressed,
              !wasBombPressed,
              SpaceInvadersProgress.useBomb()
        else {
            return
        }

        let id = context.spawn(
            Bomb.self,
            at: Vec2(
                x: (GameConfig.playerSize.x - GameConfig.bombSize.x) / 2,
                y: -GameConfig.bombSize.y
            ),
            in: .entity(state.id)
        )

        context[id]?.velocity.x = -state.velocity.x * 0.2
        context.play(sound: .boom)
        recoilTime = recoilDuration
        recoilDistance = 2
    }

    mutating func onCollision(
        context: inout Game.Context,
        state: inout EntityState,
        contact: Contact
    ) {
        guard contact.phase == .began,
              contact.target.id != nil
        else {
            return
        }

        SpaceInvadersProgress.resetBombs()
        context.play(sound: .gameover)
        context.restart()
    }

    private mutating func updateRecoil(
        context: Game.Context,
        state: inout EntityState
    ) {
        guard recoilTime > 0 else {
            state.sprite?.transform.position.y = 0
            return
        }

        recoilTime = max(recoilTime - context.delta, 0)

        let progress = 1 - (recoilTime / recoilDuration)
        let kick = sin(.degrees(progress * 180)) * recoilDistance

        state.sprite?.transform.position.y = kick
    }
}

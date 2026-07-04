import Pixl

struct Player: Entity {
    private var horizontal = AxisController(
        maxSpeed: 1000,
        acceleration: 4000,
        deceleration: 4000
    )
    private var gun = Gun(roundsPerSecond: 10)
    private var hasBomb = false
    private var seenLevelUpToken: Int?
    private var wasBombPressed = false
    private var continuousFireDuration: Double = 0
    private var didPlayEmpty = false
    private let maxContinuousFireDuration: Double = 1

    mutating func prepare(context: inout Game.PreparationContext, state: inout EntityState) {
        state.sprite = Sprite(
            material: .shape(
                RoundedRectangle(cornerRadius: 8),
                size: GameConfig.playerSize
            ),
            layer: .player,
            tint: .black
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

        updateLevelUp(context: &context)
        firePrimaryWeapon(context: &context, state: state)
        fireBomb(context: &context, state: state)
    }

    private mutating func updateLevelUp(context: inout Game.Context) {
        let levelUpToken = SpaceInvadersProgress.levelUpToken

        guard let seenLevelUpToken else {
            self.seenLevelUpToken = levelUpToken
            return
        }

        guard levelUpToken > seenLevelUpToken else {
            return
        }

        self.seenLevelUpToken = levelUpToken
        hasBomb = true
        context.play(sound: .levelup)
    }

    private mutating func firePrimaryWeapon(
        context: inout Game.Context,
        state: EntityState
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

        context.spawn(
            Bullet.self,
            at: Vec2(
                x: (GameConfig.playerSize.x - GameConfig.bulletSize.x) / 2,
                y: -GameConfig.bulletSize.y
            ),
            in: .entity(state.id)
        )
        context.play(sound: .laser)
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
              hasBomb
        else {
            return
        }

        hasBomb = false
        context.spawn(
            Bomb.self,
            at: Vec2(
                x: (GameConfig.playerSize.x - GameConfig.bombSize.x) / 2,
                y: -GameConfig.bombSize.y
            ),
            in: .entity(state.id)
        )
        context.play(sound: .boom)
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

        context.play(sound: .gameover)
        context.restart()
    }
}

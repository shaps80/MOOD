import Pixl

struct Invader: Entity {
    private enum Life {
        case alive
        case dying(elapsed: Double)
    }

    private var life: Life = .alive
    private let deathDuration: Double = 0.12

    mutating func prepare(context: inout Game.PreparationContext, state: inout EntityState) {
        state.sprite = Sprite(
            material: .shape(Circle(), size: GameConfig.invaderSize),
            layer: .enemy,
            tint: .gray
        )
        state.colliders = [
            Collider(
                bounds: Rect(size: GameConfig.invaderSize),
                layer: .invader,
                mask: .invaderContact,
                behaviour: .trigger
            ),
        ]
    }

    mutating func onUpdate(context: inout Game.Context, state: inout EntityState) {
        state.velocity = .zero

        guard case .dying(let elapsed) = life else {
            return
        }

        let nextElapsed = elapsed + context.delta
        let progress = min(nextElapsed / deathDuration, 1)
        let pulse = sin(.degrees(progress * 180))
        let scale = 1 + (0.35 * pulse)

        state.transform.scale = Vec2(scale)
        state.sprite?.tint = Int(progress * 6).isMultiple(of: 2) ? .white : .red

        if nextElapsed >= deathDuration {
            context.despawn(state.id)
        } else {
            life = .dying(elapsed: nextElapsed)
        }
    }

    mutating func onCollision(
        context: inout Game.Context,
        state: inout EntityState,
        contact: Contact
    ) {
        guard contact.phase == .began else {
            return
        }

        if contact.target.id != nil {
            guard case .alive = life else {
                return
            }

            life = .dying(elapsed: 0)
            state.colliders.removeAll()
        } else if contact.target.tile?.row == Int(GameConfig.resolution.y / GameConfig.tileSize.y) - 2 {
            context.restart()
        }
    }
}

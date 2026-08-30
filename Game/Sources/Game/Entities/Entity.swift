import Pixl
import Pixl2D

protocol Entity {
    mutating func fixedUpdate(
        _ time: FixedTime,
        collisions: CollisionWorld2D,
        context: GameContext
    )
    mutating func update(_ time: UpdateTime, context: GameContext)
    mutating func onCollision(
        _ collision: Collision2D,
        context: GameContext
    ) -> Transform2D?
    func submit(to queue: RenderQueue, context: GameContext)
}

extension Entity {
    mutating func fixedUpdate(
        _ time: FixedTime,
        collisions: CollisionWorld2D,
        context: GameContext
    ) { }
    mutating func update(_ time: UpdateTime, context: GameContext) { }
    mutating func onCollision(
        _ collision: Collision2D,
        context: GameContext
    ) -> Transform2D? { nil }
}

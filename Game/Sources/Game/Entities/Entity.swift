import Pixl

protocol Entity {
    mutating func fixedUpdate(_ time: FixedTime, context: GameContext)
    mutating func update(_ time: UpdateTime, context: GameContext)
}

extension Entity {
    mutating func fixedUpdate(_ time: FixedTime, context: GameContext) { }
    mutating func update(_ time: UpdateTime, context: GameContext) { }
}

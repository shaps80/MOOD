import Pixl

protocol Entity {
    mutating func fixedUpdate(_ time: FixedTime, context: GameContext)
    mutating func update(_ time: UpdateTime, context: GameContext)
    func submit(to queue: RenderQueue)
}

extension Entity {
    mutating func fixedUpdate(_ time: FixedTime, context: GameContext) { }
    mutating func update(_ time: UpdateTime, context: GameContext) { }
}

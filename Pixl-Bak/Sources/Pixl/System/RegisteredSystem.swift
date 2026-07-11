import Swift

struct RegisteredSystem: Sendable {
    var system: any GameSystem
    let phase: Game.Phase
}

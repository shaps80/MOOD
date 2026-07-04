import Swift

/// Frame-updated game logic that coordinates multiple entities.
///
/// Systems are for behavior that does not naturally belong to one entity, such
/// as a Space Invaders formation. They do not own entity storage; they receive
/// a narrow context for querying and moving existing entities.
public protocol GameSystem: Sendable {
    mutating func update(context: inout Game.SystemContext)
}


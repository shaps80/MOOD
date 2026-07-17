import Swift

/// Coarse platform lifecycle reported to a game.
public enum GamePhase: Hashable, Sendable {
    /// The game is not currently visible to the player.
    case background

    /// The game is visible and receiving normal interaction.
    case active

    /// The game is visible but temporarily not receiving normal interaction.
    case inactive
}

extension RandomSource.Channel {
    /// Stable channel assignments are part of the deterministic simulation
    /// contract. Existing values must never be reordered or reused.
    static let position = Self(rawValue: 0)
    static let velocity = Self(rawValue: 1)
}

import Swift

/// Produces deterministic Philox blocks from a simulation seed and stable address.
///
/// The lane layout below is part of PixlParticles' determinism contract. Changing
/// its ordering would change every generated value for existing seeds, so it must
/// not be altered without deliberately versioning the simulation format.
///
/// - The seed's low and high 32 bits map to key lanes `x0` and `x1`.
/// - The address's low and high 32 bits map to counter lanes `x0` and `x1`.
/// - Counter lanes `x2` and `x3` are reserved and currently remain zero.
struct RandomSource {
    private let key: Philox4x32.Key

    @inline(__always)
    init(seed: UInt64) {
        key = .init(
            UInt32(truncatingIfNeeded: seed),
            UInt32(truncatingIfNeeded: seed >> 32)
        )
    }

    @inline(__always)
    func block(at address: UInt64) -> Philox4x32.Counter {
        Philox4x32.generate(
            counter: .init(
                UInt32(truncatingIfNeeded: address),
                UInt32(truncatingIfNeeded: address >> 32),
                0,
                0
            ),
            key: key
        )
    }
}

import Swift

/// Produces deterministic Philox blocks from a simulation seed and stable address.
///
/// The lane layout below is part of PixlParticles' determinism contract. Changing
/// its ordering would change every generated value for existing seeds, so it must
/// not be altered without deliberately versioning the simulation format.
///
/// - The seed's low and high 32 bits map to key lanes `x0` and `x1`.
/// - The address's low and high 32 bits map to counter lanes `x0` and `x1`.
/// - The channel maps to counter lane `x2` and isolates unrelated properties.
/// - The index maps to counter lane `x3` and selects another block in a channel.
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
    func block(
        at address: UInt64,
        channel: UInt32 = 0,
        index: UInt32 = 0
    ) -> Philox4x32.Counter {
        Philox4x32.generate(
            counter: .init(
                UInt32(truncatingIfNeeded: address),
                UInt32(truncatingIfNeeded: address >> 32),
                channel,
                index
            ),
            key: key
        )
    }

    /// Maps the upper 24 bits of a random word uniformly onto `[0, 1)`.
    ///
    /// This mapping is part of PixlParticles' determinism contract. Every input
    /// integer and the power-of-two scale are exactly representable by `Float`,
    /// so the conversion requires no platform-dependent rounding.
    @inline(__always)
    static func unitFloat(from word: UInt32) -> Float {
        Float(word >> 8) * 0x1p-24
    }

    /// Maps a random word uniformly into a finite, half-open `Float` range.
    ///
    /// The upper-bound clamp preserves half-open range semantics when floating-
    /// point rounding would otherwise produce `range.upperBound`.
    @inline(__always)
    static func float(from word: UInt32, in range: Range<Float>) -> Float {
        let unit = unitFloat(from: word)
        let width = range.upperBound - range.lowerBound
        let value = range.lowerBound + unit * width

        return Swift.min(value, range.upperBound.nextDown)
    }

    /// Maps a random word uniformly into a finite, closed `Float` range.
    ///
    /// The endpoint branches guarantee that both bounds are reachable exactly.
    /// Interior values divide by `16_777_215`, preserving 24 equally probable
    /// source values without bias from a pre-rounded reciprocal.
    @inline(__always)
    static func float(from word: UInt32, in range: ClosedRange<Float>) -> Float {
        let sample = word >> 8

        if sample == 0 {
            return range.lowerBound
        }

        if sample == 0x00FFFFFF {
            return range.upperBound
        }

        let unit = Float(sample) / 16_777_215
        let width = range.upperBound - range.lowerBound

        return range.lowerBound + unit * width
    }
}

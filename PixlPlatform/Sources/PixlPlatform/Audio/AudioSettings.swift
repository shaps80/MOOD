import Swift

/// Fixed audio-resource capacities reserved by a platform adapter.
public struct AudioSettings: Hashable, Sendable {
    /// Maximum number of resident sounds.
    public let maxSoundCount: UInt32
    /// Maximum number of simultaneous playback voices.
    public let maxVoiceCount: UInt32
    /// Maximum number of additional mixing buses.
    public let maxBusCount: UInt32

    /// Creates positive fixed capacities for audio resources.
    /// - Parameters:
    ///   - maxSoundCount: Maximum number of resident sounds.
    ///   - maxVoiceCount: Maximum number of simultaneous playback voices.
    ///   - maxBusCount: Maximum number of additional mixing buses.
    public init(
        maxSoundCount: UInt32 = 128,
        maxVoiceCount: UInt32 = 64,
        maxBusCount: UInt32 = 8
    ) {
        precondition(maxSoundCount > 0, "Maximum sound count must be greater than zero")
        precondition(maxVoiceCount > 0, "Maximum voice count must be greater than zero")
        precondition(maxBusCount > 0, "Maximum bus count must be greater than zero")

        self.maxSoundCount = maxSoundCount
        self.maxVoiceCount = maxVoiceCount
        self.maxBusCount = maxBusCount
    }

    /// Standard audio capacities suitable for an ordinary game.
    public static let `default`: Self = .init()
}

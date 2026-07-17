import Swift

public struct AudioSettings: Hashable, Sendable {
    public let maxSoundCount: UInt32
    public let maxVoiceCount: UInt32
    public let maxBusCount: UInt32

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

    public static let `default`: Self = .init()
}

import Swift

public enum ChannelLayout: Hashable, Sendable {
    case mono
    case stereo

    public var channelCount: UInt32 {
        switch self {
        case .mono: 1
        case .stereo: 2
        }
    }
}

public struct SoundDescriptor: Hashable, Sendable {
    public let sampleRate: UInt32
    public let channelLayout: ChannelLayout
    public let frameCount: UInt32

    public init(
        sampleRate: UInt32,
        channelLayout: ChannelLayout,
        frameCount: UInt32
    ) {
        precondition(sampleRate > 0, "Sound sample rate must be greater than zero")
        precondition(frameCount > 0, "Sound frame count must be greater than zero")

        self.sampleRate = sampleRate
        self.channelLayout = channelLayout
        self.frameCount = frameCount
    }

    public var duration: Double {
        Double(frameCount) / Double(sampleRate)
    }

    package var sampleCount: Int? {
        let result = Int(frameCount).multipliedReportingOverflow(
            by: Int(channelLayout.channelCount)
        )
        return result.overflow ? nil : result.partialValue
    }
}

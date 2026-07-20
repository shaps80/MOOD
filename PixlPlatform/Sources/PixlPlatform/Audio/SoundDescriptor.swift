import Swift

/// Supported interleaved sound channel arrangements.
public enum ChannelLayout: Hashable, Sendable {
    /// One channel per frame.
    case mono
    /// Left and right channels per frame.
    case stereo

    /// Number of samples stored in each frame.
    public var channelCount: UInt32 {
        switch self {
        case .mono: 1
        case .stereo: 2
        }
    }
}

/// Format and length of interleaved floating-point sound samples.
public struct SoundDescriptor: Hashable, Sendable {
    /// Frames played per second.
    public let sampleRate: UInt32
    /// Number and meaning of channels in each frame.
    public let channelLayout: ChannelLayout
    /// Number of sample frames.
    public let frameCount: UInt32

    /// Creates a sound description.
    /// - Parameters:
    ///   - sampleRate: Positive frame rate in hertz.
    ///   - channelLayout: Channel arrangement of each frame.
    ///   - frameCount: Positive number of frames.
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

    /// Playback duration in seconds at the original rate.
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

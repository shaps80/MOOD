import Swift

/// A category of audio resource involved in an error.
public enum AudioResourceKind: Hashable, Sendable {
    /// Resident sample data.
    case sound
    /// One active or paused playback voice.
    case voice
    /// A mixing bus.
    case bus
}

/// An audio-device operation failure.
public enum AudioError: Error, Hashable, Sendable {
    /// Interleaved sample count does not match the sound descriptor.
    case invalidSampleCount(expected: Int, actual: Int)
    /// A referenced resource has been destroyed or belongs to another device.
    case resourceUnavailable(AudioResourceKind)
    /// The device could not allocate or create a resource.
    case resourceCreationFailed(AudioResourceKind)
}

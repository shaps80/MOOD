import Swift

public enum AudioResourceKind: Hashable, Sendable {
    case sound
    case voice
    case bus
}

public enum AudioError: Error, Hashable, Sendable {
    case invalidSampleCount(expected: Int, actual: Int)
    case resourceCreationFailed(AudioResourceKind)
}

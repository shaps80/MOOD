import Swift

public protocol SoundWriter: Sendable {
    func write(
        copying samples: [Float],
        descriptor: SoundDescriptor
    ) async throws(AudioError)
}

import Swift

/// Asynchronous replacement access to one existing sound resource.
public protocol SoundWriter: Sendable {
    /// Replaces the sound's complete sample contents.
    /// - Parameters:
    ///   - samples: Interleaved normalized samples matching `descriptor`.
    ///   - descriptor: Format and frame count describing `samples`.
    /// - Throws: ``AudioError`` when samples are invalid, the sound is unavailable, or replacement fails.
    func write(
        copying samples: [Float],
        descriptor: SoundDescriptor
    ) async throws(AudioError)

    /// Ends pending access and prevents future writes through this writer.
    func invalidate() async
}

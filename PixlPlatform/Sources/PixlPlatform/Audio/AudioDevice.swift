import Swift

/// Low-level audio resource and playback capability supplied by a platform adapter.
public protocol AudioDevice: AnyObject {
    /// Creates a resident sound by copying interleaved floating-point samples.
    /// - Parameters:
    ///   - samples: Interleaved normalized samples matching `descriptor`.
    ///   - descriptor: Sample rate, channel layout, and frame count describing `samples`.
    /// - Returns: An opaque sound owned by this device.
    /// - Throws: ``AudioError`` when samples are invalid or the resource cannot be created.
    func makeSound(
        copying samples: [Float],
        descriptor: SoundDescriptor
    ) throws(AudioError) -> Sound

    /// Requests asynchronous replacement access for an existing sound.
    /// - Parameter sound: Live sound created by this device.
    /// - Returns: A writer when supported, otherwise `nil`.
    func soundWriter(for sound: Sound) -> (any SoundWriter)?

    /// Invalidates a sound and releases its device-owned resource.
    /// - Parameter sound: Sound created by this device. Copies become stale after destruction.
    func destroy(_ sound: Sound)

    /// Creates reusable playback controls without beginning playback.
    /// - Parameters:
    ///   - sound: Sound to play.
    ///   - bus: Bus receiving the playback.
    /// - Returns: A playback controller configured for `sound` and `bus`.
    func prepare(_ sound: Sound, on bus: Bus) -> Playback

    /// Creates an independently adjustable mixing bus.
    /// - Returns: A bus owned by this device.
    /// - Throws: ``AudioError/resourceCreationFailed(_:)`` when capacity or backend creation fails.
    func makeBus() throws(AudioError) -> Bus

    /// Root bus through which all device audio is mixed.
    var masterBus: Bus { get }
    /// Nonnegative output gain applied after bus and playback volume.
    var masterVolume: Float { get set }
}

public extension AudioDevice {
    /// Returns `nil`; adapters override this when live sound replacement is supported.
    /// - Parameter sound: Sound for which replacement access is requested.
    /// - Returns: Always `nil` in the default implementation.
    func soundWriter(for sound: Sound) -> (any SoundWriter)? {
        nil
    }
}

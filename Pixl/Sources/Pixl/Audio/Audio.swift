import PixlPlatform
import Swift

/// Game-facing access to resident playback and flat mixing buses.
public final class Audio {
    private let device: any AudioDevice
    /// Root bus receiving all audio output.
    public let masterBus: Bus

    init(device: any AudioDevice) {
        self.device = device
        masterBus = device.masterBus
    }

    /// Creates reusable playback controls without starting the sound.
    /// - Parameter sound: Resident sound asset to prepare.
    /// - Returns: Playback routed to ``masterBus``.
    public func prepare(_ sound: SoundAsset) -> Playback {
        device.prepare(sound.sound, on: masterBus)
    }

    /// Creates an independently adjustable mixing bus.
    /// - Returns: A new flat bus on the game's audio device.
    /// - Throws: ``AudioError`` when bus capacity or backend creation fails.
    public func makeBus() throws(AudioError) -> Bus {
        try device.makeBus()
    }

    /// Nonnegative linear gain applied to final game audio output.
    public var masterVolume: Float {
        get {
            device.masterVolume
        }
        set {
            device.masterVolume = newValue
        }
    }
}

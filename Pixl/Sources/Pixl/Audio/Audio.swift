import PixlPlatform
import Swift

public final class Audio {
    private let device: (any AudioDevice)?

    init(device: (any AudioDevice)?) {
        self.device = device
    }

    public func makeBus() -> Bus? {
        device?.makeBus()
    }

    @discardableResult
    public func play(
        _ sound: SoundAsset,
        on bus: Bus? = nil,
        volume: Float = 1,
        pan: Float = 0,
        looping: Bool = false,
        rate: Float = 1
    ) -> Playback? {
        device?.play(
            sound.sound,
            on: bus,
            volume: volume,
            pan: pan,
            looping: looping,
            rate: rate
        )
    }

    public func pause(_ playback: Playback) {
        device?.pause(playback)
    }

    public func resume(_ playback: Playback) {
        device?.resume(playback)
    }

    public func stop(_ playback: Playback) {
        device?.stop(playback)
    }

    public func setVolume(
        _ volume: Float,
        for playback: Playback
    ) {
        device?.setVolume(volume, for: playback)
    }

    public func setPan(
        _ pan: Float,
        for playback: Playback
    ) {
        device?.setPan(pan, for: playback)
    }

    public func setRate(
        _ rate: Float,
        for playback: Playback
    ) {
        device?.setRate(rate, for: playback)
    }

    public func setVolume(
        _ volume: Float,
        for bus: Bus
    ) {
        device?.setVolume(volume, for: bus)
    }

    public func setMasterVolume(_ volume: Float) {
        device?.setMasterVolume(volume)
    }
}

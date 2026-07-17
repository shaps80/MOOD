import PixlPlatform
import Swift

public final class Audio {
    private let device: any AudioDevice

    init(device: any AudioDevice) {
        self.device = device
    }

    public func makeBus() -> Bus? {
        device.makeBus()
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
        device.play(
            sound.sound,
            on: bus,
            volume: volume,
            pan: pan,
            looping: looping,
            rate: rate
        )
    }

    public func pause(_ playback: Playback) {
        device.pause(playback)
    }

    public func resume(_ playback: Playback) {
        device.resume(playback)
    }

    public func stop(_ playback: Playback) {
        device.stop(playback)
    }

    public subscript(volume playback: Playback) -> Float {
        get {
            device[volume: playback]
        }
        set {
            device[volume: playback] = newValue
        }
    }

    public subscript(pan playback: Playback) -> Float {
        get {
            device[pan: playback]
        }
        set {
            device[pan: playback] = newValue
        }
    }

    public subscript(rate playback: Playback) -> Float {
        get {
            device[rate: playback]
        }
        set {
            device[rate: playback] = newValue
        }
    }

    public subscript(volume bus: Bus) -> Float {
        get {
            device[volume: bus]
        }
        set {
            device[volume: bus] = newValue
        }
    }

    public var masterVolume: Float {
        get {
            device.masterVolume
        }
        set {
            device.masterVolume = newValue
        }
    }
}

import PixlPlatform
import Swift

public final class Audio {
    private let device: any AudioDevice
    public let masterBus: Bus

    init(device: any AudioDevice) {
        self.device = device
        masterBus = device.masterBus
    }

    public func prepare(_ sound: SoundAsset) -> Playback {
        device.prepare(sound.sound, on: masterBus)
    }

    public func makeBus() throws(AudioError) -> Bus {
        try device.makeBus()
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

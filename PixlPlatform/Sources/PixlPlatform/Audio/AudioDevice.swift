import Swift

public protocol AudioDevice: AnyObject {
    func makeSound(
        copying samples: [Float],
        descriptor: SoundDescriptor
    ) throws(AudioError) -> Sound

    func soundWriter(for sound: Sound) -> (any SoundWriter)?

    func destroy(_ sound: Sound)

    func prepare(_ sound: Sound, on bus: Bus) -> Playback

    func makeBus() throws(AudioError) -> Bus

    var masterBus: Bus { get }
    var masterVolume: Float { get set }
}

public extension AudioDevice {
    func soundWriter(for sound: Sound) -> (any SoundWriter)? {
        nil
    }
}

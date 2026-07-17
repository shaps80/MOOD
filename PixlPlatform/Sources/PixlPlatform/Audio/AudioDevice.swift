import Swift

public protocol AudioDevice: AnyObject {
    func makeSound(
        copying samples: [Float],
        descriptor: SoundDescriptor
    ) throws(AudioError) -> Sound

    func soundWriter(for sound: Sound) -> (any SoundWriter)?

    func destroy(_ sound: Sound)

    func makeBus() -> Bus?

    func play(
        _ sound: Sound,
        on bus: Bus?,
        volume: Float,
        pan: Float,
        looping: Bool,
        rate: Float
    ) -> Playback?

    func pause(_ playback: Playback)
    func resume(_ playback: Playback)
    func stop(_ playback: Playback)

    func setVolume(_ volume: Float, for playback: Playback)
    func setPan(_ pan: Float, for playback: Playback)
    func setRate(_ rate: Float, for playback: Playback)

    func setVolume(_ volume: Float, for bus: Bus)
    func setMasterVolume(_ volume: Float)
}

public extension AudioDevice {
    func soundWriter(for sound: Sound) -> (any SoundWriter)? {
        nil
    }
}

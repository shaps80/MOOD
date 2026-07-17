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

    subscript(volume playback: Playback) -> Float { get set }
    subscript(pan playback: Playback) -> Float { get set }
    subscript(rate playback: Playback) -> Float { get set }
    subscript(volume bus: Bus) -> Float { get set }

    var masterVolume: Float { get set }
}

public extension AudioDevice {
    func soundWriter(for sound: Sound) -> (any SoundWriter)? {
        nil
    }
}

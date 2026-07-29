import PixlSynchronization
import Swift

package final class AudioCompletion: Sendable {
    private let finished = AtomicFlag(false)

    package init() {}

    package func finish() {
        finished.store(true)
    }

    package var isFinished: Bool {
        finished.load()
    }
}

package protocol AudioBackend: AnyObject {
    associatedtype SoundResource
    associatedtype VoiceResource
    associatedtype BusResource

    func makeSound(
        copying samples: [Float],
        descriptor: SoundDescriptor
    ) throws(AudioError) -> SoundResource

    func makeBus() -> BusResource?
    func destroy(_ bus: BusResource)

    func play(
        _ sound: SoundResource,
        on bus: BusResource?,
        volume: Float,
        pan: Float,
        looping: Bool,
        rate: Float,
        completion: AudioCompletion
    ) throws(AudioError) -> VoiceResource

    func pause(_ voice: VoiceResource)
    func resume(_ voice: VoiceResource)
    func stop(_ voice: VoiceResource)
    func destroy(_ voice: VoiceResource)
    func isFinished(_ voice: VoiceResource) -> Bool

    func setVolume(_ volume: Float, for voice: VoiceResource)
    func setPan(_ pan: Float, for voice: VoiceResource)
    func setRate(_ rate: Float, for voice: VoiceResource)

    func setVolume(_ volume: Float, for bus: BusResource)
    func setMasterVolume(_ volume: Float)
}

extension AudioBackend {
    package func isFinished(_ voice: VoiceResource) -> Bool {
        false
    }
}

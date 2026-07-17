#if os(macOS)
@preconcurrency import AVFAudio
@preconcurrency import Dispatch
@preconcurrency import Foundation
import PixlPlatform
import PixlPlatformSynchronization
import Swift

package final class MetalSoundResource: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer

    init(buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }
}

package final class MetalBusResource: @unchecked Sendable {
    fileprivate var mixer: AVAudioMixerNode?
    fileprivate var connectionCount = 0
    fileprivate var isDestroyed = false
}

package final class MetalVoiceResource: @unchecked Sendable {
    let sound: MetalSoundResource
    fileprivate var player: AVAudioPlayerNode?
    fileprivate var varispeed: AVAudioUnitVarispeed?
    fileprivate var bus: MetalBusResource?
    fileprivate var isDestroyed = false

    init(sound: MetalSoundResource) {
        self.sound = sound
    }
}

package final class MetalAudioBackend: AudioBackend {
    private let audioQueue: DispatchQueue
    private let state: MetalAudioState

    package init?(engine: AVAudioEngine? = nil) {
        let audioQueue = DispatchQueue(
            label: "dev.pixl.audio.control",
            qos: .utility
        )
        guard let state = audioQueue.sync(execute: {
            MetalAudioState(
                engine: engine ?? AVAudioEngine(),
                queue: audioQueue
            )
        }) else {
            return nil
        }
        self.audioQueue = audioQueue
        self.state = state
    }

    deinit {
        audioQueue.sync {
            state.shutdown()
        }
    }

    package func makeSound(
        copying samples: [Float],
        descriptor: SoundDescriptor
    ) throws(AudioError) -> MetalSoundResource {
        do {
            return try audioQueue.sync {
                try state.makeSound(
                    copying: samples,
                    descriptor: descriptor
                )
            }
        } catch let error as AudioError {
            throw error
        } catch {
            throw .resourceCreationFailed(.sound)
        }
    }

    package func makeBus() -> MetalBusResource? {
        let bus = MetalBusResource()
        audioQueue.async { [state, bus] in
            state.makeBus(bus)
        }
        return bus
    }

    package func destroy(_ bus: MetalBusResource) {
        audioQueue.async { [state, bus] in
            state.destroy(bus)
        }
    }

    package func play(
        _ sound: MetalSoundResource,
        on bus: MetalBusResource?,
        volume: Float,
        pan: Float,
        looping: Bool,
        rate: Float,
        completion: AudioCompletion
    ) throws(AudioError) -> MetalVoiceResource {
        let voice = MetalVoiceResource(sound: sound)
        audioQueue.async { [state, voice, bus] in
            state.play(
                voice,
                on: bus,
                volume: volume,
                pan: pan,
                looping: looping,
                rate: rate,
                completion: completion
            )
        }
        return voice
    }

    package func pause(_ voice: MetalVoiceResource) {
        audioQueue.async { [state, voice] in
            state.pause(voice)
        }
    }

    package func resume(_ voice: MetalVoiceResource) {
        audioQueue.async { [state, voice] in
            state.resume(voice)
        }
    }

    package func stop(_ voice: MetalVoiceResource) {
        audioQueue.async { [state, voice] in
            state.stop(voice)
        }
    }

    package func destroy(_ voice: MetalVoiceResource) {
        audioQueue.async { [state, voice] in
            state.destroy(voice)
        }
    }

    package func setVolume(
        _ volume: Float,
        for voice: MetalVoiceResource
    ) {
        audioQueue.async { [state, voice] in
            state.setVolume(volume, for: voice)
        }
    }

    package func setPan(
        _ pan: Float,
        for voice: MetalVoiceResource
    ) {
        audioQueue.async { [state, voice] in
            state.setPan(pan, for: voice)
        }
    }

    package func setRate(
        _ rate: Float,
        for voice: MetalVoiceResource
    ) {
        audioQueue.async { [state, voice] in
            state.setRate(rate, for: voice)
        }
    }

    package func setVolume(
        _ volume: Float,
        for bus: MetalBusResource
    ) {
        audioQueue.async { [state, bus] in
            state.setVolume(volume, for: bus)
        }
    }

    package func setMasterVolume(_ volume: Float) {
        audioQueue.async { [state] in
            state.setMasterVolume(volume)
        }
    }
}

private final class MetalAudioState: @unchecked Sendable {
    private let engine: AVAudioEngine
    private let queue: DispatchQueue
    private let recoveryScheduled = AtomicFlag(false)
    private var configurationObserver: NSObjectProtocol?
    private var isShutdown = false

    init?(
        engine: AVAudioEngine,
        queue: DispatchQueue
    ) {
        self.engine = engine
        self.queue = queue
        _ = engine.mainMixerNode
        guard ensureEngineRunning(reportingRecovery: false) else {
            return nil
        }
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self] _ in
            self?.scheduleRecovery()
        }
    }

    func shutdown() {
        dispatchPrecondition(condition: .onQueue(queue))
        guard !isShutdown else { return }
        isShutdown = true
        if let configurationObserver {
            NotificationCenter.default.removeObserver(
                configurationObserver
            )
            self.configurationObserver = nil
        }
        engine.stop()
    }

    func makeSound(
        copying samples: [Float],
        descriptor: SoundDescriptor
    ) throws(AudioError) -> MetalSoundResource {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(descriptor.sampleRate),
            channels: AVAudioChannelCount(
                descriptor.channelLayout.channelCount
            ),
            interleaved: false
        ),
        let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(descriptor.frameCount)
        ),
        let channels = buffer.floatChannelData
        else {
            throw .resourceCreationFailed(.sound)
        }

        buffer.frameLength = AVAudioFrameCount(descriptor.frameCount)
        samples.withUnsafeBufferPointer { source in
            let frameCount = Int(descriptor.frameCount)
            var channel = 0
            while channel < Int(descriptor.channelLayout.channelCount) {
                channels[channel].update(
                    from: source.baseAddress!.advanced(
                        by: channel * frameCount
                    ),
                    count: frameCount
                )
                channel += 1
            }
        }
        return MetalSoundResource(buffer: buffer)
    }

    func makeBus(_ bus: MetalBusResource) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard !isShutdown, !bus.isDestroyed else { return }
        let mixer = AVAudioMixerNode()
        engine.attach(mixer)
        bus.mixer = mixer
    }

    func destroy(_ bus: MetalBusResource) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard !bus.isDestroyed else { return }
        bus.isDestroyed = true
        guard let mixer = bus.mixer else { return }
        engine.disconnectNodeOutput(mixer)
        engine.detach(mixer)
        bus.mixer = nil
    }

    func play(
        _ voice: MetalVoiceResource,
        on bus: MetalBusResource?,
        volume: Float,
        pan: Float,
        looping: Bool,
        rate: Float,
        completion: AudioCompletion
    ) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard !voice.isDestroyed,
              ensureEngineRunning()
        else {
            completion.finish()
            return
        }

        let target: AVAudioNode
        if let bus {
            guard !bus.isDestroyed, let mixer = bus.mixer else {
                completion.finish()
                return
            }
            target = mixer
        } else {
            target = engine.mainMixerNode
        }

        let player = AVAudioPlayerNode()
        let varispeed = AVAudioUnitVarispeed()
        engine.attach(player)
        engine.attach(varispeed)
        engine.connect(
            player,
            to: varispeed,
            format: voice.sound.buffer.format
        )
        engine.connect(
            varispeed,
            to: target,
            format: voice.sound.buffer.format
        )
        if let bus, let mixer = bus.mixer {
            if bus.connectionCount == 0 {
                engine.connect(
                    mixer,
                    to: engine.mainMixerNode,
                    format: nil
                )
            }
            bus.connectionCount += 1
            voice.bus = bus
        }
        player.volume = volume
        player.pan = pan
        varispeed.rate = rate
        player.scheduleBuffer(
            voice.sound.buffer,
            at: nil,
            options: looping ? [.loops] : [],
            completionCallbackType: .dataPlayedBack
        ) { _ in
            completion.finish()
        }
        voice.player = player
        voice.varispeed = varispeed
        player.play()
    }

    func pause(_ voice: MetalVoiceResource) {
        dispatchPrecondition(condition: .onQueue(queue))
        voice.player?.pause()
    }

    func resume(_ voice: MetalVoiceResource) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard ensureEngineRunning() else { return }
        voice.player?.play()
    }

    func stop(_ voice: MetalVoiceResource) {
        dispatchPrecondition(condition: .onQueue(queue))
        voice.player?.stop()
    }

    func destroy(_ voice: MetalVoiceResource) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard !voice.isDestroyed else { return }
        voice.isDestroyed = true
        voice.player?.stop()
        if let player = voice.player {
            engine.disconnectNodeOutput(player)
            engine.detach(player)
        }
        if let varispeed = voice.varispeed {
            engine.disconnectNodeOutput(varispeed)
            engine.detach(varispeed)
        }
        if let bus = voice.bus {
            bus.connectionCount -= 1
            if bus.connectionCount == 0, let mixer = bus.mixer {
                engine.disconnectNodeOutput(mixer)
            }
        }
        voice.player = nil
        voice.varispeed = nil
        voice.bus = nil
    }

    func setVolume(
        _ volume: Float,
        for voice: MetalVoiceResource
    ) {
        dispatchPrecondition(condition: .onQueue(queue))
        voice.player?.volume = volume
    }

    func setPan(
        _ pan: Float,
        for voice: MetalVoiceResource
    ) {
        dispatchPrecondition(condition: .onQueue(queue))
        voice.player?.pan = pan
    }

    func setRate(
        _ rate: Float,
        for voice: MetalVoiceResource
    ) {
        dispatchPrecondition(condition: .onQueue(queue))
        voice.varispeed?.rate = rate
    }

    func setVolume(
        _ volume: Float,
        for bus: MetalBusResource
    ) {
        dispatchPrecondition(condition: .onQueue(queue))
        bus.mixer?.outputVolume = volume
    }

    func setMasterVolume(_ volume: Float) {
        dispatchPrecondition(condition: .onQueue(queue))
        engine.mainMixerNode.outputVolume = volume
    }

    private func scheduleRecovery() {
        guard !recoveryScheduled.exchange(true) else { return }
        queue.async { [weak self] in
            guard let self else { return }
            recoveryScheduled.store(false)
            _ = ensureEngineRunning()
        }
    }

    private func ensureEngineRunning(
        reportingRecovery: Bool = true
    ) -> Bool {
        dispatchPrecondition(condition: .onQueue(queue))
        guard !isShutdown else { return false }
        guard !engine.isRunning else { return true }

        if reportingRecovery {
            print("Audio output changed; restarting audio engine")
        }
        engine.prepare()
        do {
            try engine.start()
            return true
        } catch {
            print("Unable to restart audio engine: \(error)")
            return false
        }
    }
}
#endif

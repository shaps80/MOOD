import PixlSynchronization
import Swift

package final class AudioEngine<Backend: AudioBackend>: AudioDevice, AudioController, @unchecked Sendable {
    private struct SoundRecord {
        var resource: Backend.SoundResource?
    }

    private struct VoiceRecord {
        var resource: Backend.VoiceResource
        var completion: AudioCompletion
        let soundID: ResourceID
        let busID: ResourceID?
        var volume: Float
        var pan: Float
        let looping: Bool
        var rate: Float
        var isPaused: Bool
    }

    private struct BusRecord {
        var resource: Backend.BusResource
        var volume: Float
    }

    private struct State {
        let backend: Backend
        let sounds: ResourcePool<SoundRecord>
        let voices: ResourcePool<VoiceRecord>
        let buses: ResourcePool<BusRecord>
        var masterVolume: Float
    }

    private let state: CriticalState<State>

    package init(
        backend: Backend,
        settings: AudioSettings
    ) {
        state = CriticalState(
            State(
                backend: backend,
                sounds: ResourcePool(capacity: settings.maxSoundCount),
                voices: ResourcePool(capacity: settings.maxVoiceCount),
                buses: ResourcePool(capacity: settings.maxBusCount),
                masterVolume: 1
            )
        )
    }

    deinit {
        state.withLock { state in
            state.voices.removeAll { voice in
                state.backend.stop(voice.pointee.resource)
                state.backend.destroy(voice.pointee.resource)
                return true
            }
            state.buses.removeAll { bus in
                state.backend.destroy(bus.pointee.resource)
                return true
            }
        }
    }

    package func makeSound(
        copying samples: [Float],
        descriptor: SoundDescriptor
    ) throws(AudioError) -> Sound {
        try validate(samples, descriptor: descriptor)

        return try state.withLock { state throws(AudioError) in
            guard state.sounds.count < state.sounds.capacity else {
                throw .resourceCreationFailed(.sound)
            }
            let resource = try state.backend.makeSound(
                copying: samples,
                descriptor: descriptor
            )
            guard let id = state.sounds.insert(
                SoundRecord(resource: resource)
            ) else {
                throw .resourceCreationFailed(.sound)
            }
            return Sound(id: id)
        }
    }

    package func soundWriter(
        for sound: Sound
    ) -> (any SoundWriter)? {
        state.withLock { state in
            guard state.sounds.contains(sound.id) else { return nil }
            return EngineSoundWriter(engine: self, sound: sound)
        }
    }

    package func destroy(_ sound: Sound) {
        state.withLock { state in
            stopVoices(for: sound.id, state)
            _ = state.sounds.remove(sound.id)
        }
    }

    package func prepare(
        _ sound: Sound,
        on bus: Bus
    ) -> Playback {
        Playback(controller: self, sound: sound, bus: bus)
    }

    package func makeBus() throws(AudioError) -> Bus {
        try state.withLock { state throws(AudioError) in
            guard state.buses.count < state.buses.capacity,
                  let resource = state.backend.makeBus()
            else {
                throw .resourceCreationFailed(.bus)
            }
            guard let id = state.buses.insert(
                BusRecord(resource: resource, volume: 1)
            ) else {
                state.backend.destroy(resource)
                throw .resourceCreationFailed(.bus)
            }
            return Bus(controller: self, id: id)
        }
    }

    package var masterBus: Bus {
        Bus(controller: self, id: nil)
    }

    package func play(
        _ playback: Playback
    ) throws(AudioError) {
        if let voiceID = playback.voiceID {
            let resumed = withLiveVoice(voiceID) { backend, voice in
                if voice.pointee.isPaused {
                    backend.resume(voice.pointee.resource)
                    voice.pointee.isPaused = false
                }
                return true
            } ?? false
            if resumed {
                return
            }
            playback.voiceID = nil
        }

        try state.withLock { state throws(AudioError) in
            if state.voices.count == state.voices.capacity {
                reapFinishedVoices(state)
            }
            guard state.voices.count < state.voices.capacity else {
                throw .resourceCreationFailed(.voice)
            }

            guard let soundRecord = state.sounds.withValue(
                for: playback.sound.id,
                { $0.pointee }
            ), let soundResource = soundRecord.resource else {
                throw .resourceUnavailable(.sound)
            }

            let busResource: Backend.BusResource?
            if let busID = playback.bus.id {
                guard let resource = state.buses.withValue(
                    for: busID,
                    { $0.pointee.resource }
                ) else {
                    throw .resourceUnavailable(.bus)
                }
                busResource = resource
            } else {
                busResource = nil
            }

            let completion = AudioCompletion()
            let resource = try state.backend.play(
                soundResource,
                on: busResource,
                volume: playback.volume,
                pan: playback.pan,
                looping: playback.loop,
                rate: playback.rate,
                completion: completion
            )
            guard let id = state.voices.insert(
                VoiceRecord(
                        resource: resource,
                        completion: completion,
                        soundID: playback.sound.id,
                        busID: playback.bus.id,
                        volume: playback.volume,
                        pan: playback.pan,
                        looping: playback.loop,
                        rate: playback.rate,
                        isPaused: false
                    )
            ) else {
                state.backend.stop(resource)
                state.backend.destroy(resource)
                throw .resourceCreationFailed(.voice)
            }
            playback.voiceID = id
        }
    }

    package func pause(_ playback: Playback) {
        guard let voiceID = playback.voiceID else { return }
        withLiveVoice(voiceID) { backend, voice in
            backend.pause(voice.pointee.resource)
            voice.pointee.isPaused = true
        }
    }

    package func stop(_ playback: Playback) {
        guard let voiceID = playback.voiceID else { return }
        playback.voiceID = nil
        state.withLock { state in
            guard let _ = state.voices.withValue(
                for: voiceID,
                { voice in
                    state.backend.stop(voice.pointee.resource)
                    state.backend.destroy(voice.pointee.resource)
                }
            ) else {
                return
            }
            _ = state.voices.remove(voiceID)
        }
    }

    package func setVolume(for playback: Playback) {
        guard let voiceID = playback.voiceID else { return }
        withLiveVoice(voiceID) { backend, voice in
            backend.setVolume(
                playback.volume,
                for: voice.pointee.resource
            )
            voice.pointee.volume = playback.volume
        }
    }

    package func setPan(for playback: Playback) {
        guard let voiceID = playback.voiceID else { return }
        withLiveVoice(voiceID) { backend, voice in
            backend.setPan(playback.pan, for: voice.pointee.resource)
            voice.pointee.pan = playback.pan
        }
    }

    package func setRate(for playback: Playback) {
        guard let voiceID = playback.voiceID else { return }
        withLiveVoice(voiceID) { backend, voice in
            backend.setRate(playback.rate, for: voice.pointee.resource)
            voice.pointee.rate = playback.rate
        }
    }

    package func volume(for bus: Bus) -> Float {
        guard let busID = bus.id else { return masterVolume }
        return state.withLock { state in
            state.buses.withValue(for: busID) { bus in
                bus.pointee.volume
            } ?? 0
        }
    }

    package func setVolume(_ volume: Float, for bus: Bus) {
        guard let busID = bus.id else {
            masterVolume = volume
            return
        }
        state.withLock { state in
            _ = state.buses.update(busID) { bus in
                state.backend.setVolume(
                    volume,
                    for: bus.pointee.resource
                )
                bus.pointee.volume = volume
            }
        }
    }

    package var masterVolume: Float {
        get {
            state.withLock { $0.masterVolume }
        }
        set {
            preconditionVolume(newValue)
            state.withLock { state in
                state.backend.setMasterVolume(newValue)
                state.masterVolume = newValue
            }
        }
    }

    fileprivate func replace(
        _ sound: Sound,
        copying samples: [Float],
        descriptor: SoundDescriptor
    ) throws(AudioError) {
        try validate(samples, descriptor: descriptor)

        try state.withLock { state throws(AudioError) in
            guard state.sounds.contains(sound.id) else {
                throw .resourceCreationFailed(.sound)
            }
            let replacement = try state.backend.makeSound(
                copying: samples,
                descriptor: descriptor
            )
            guard state.sounds.update(sound.id, { sound in
                sound.pointee.resource = replacement
            }) != nil else {
                throw .resourceCreationFailed(.sound)
            }
            restartVoices(
                for: sound.id,
                using: replacement,
                state
            )
        }
    }

    fileprivate func invalidate(_ sound: Sound) {
        state.withLock { state in
            guard state.sounds.update(sound.id, { sound in
                sound.pointee.resource = nil
            }) != nil else {
                return
            }
            stopVoices(for: sound.id, state)
        }
    }

    private func withLiveVoice<Result>(
        _ voiceID: ResourceID,
        _ body: (
            Backend,
            UnsafeMutablePointer<VoiceRecord>
        ) -> Result
    ) -> Result? {
        state.withLock { state -> Result? in
            guard let finished = state.voices.withValue(
                for: voiceID,
                {
                    $0.pointee.completion.isFinished
                        || state.backend.isFinished($0.pointee.resource)
                }
            ) else {
                return nil
            }
            if finished {
                disposeVoice(voiceID, state)
                return nil
            }
            return state.voices.update(voiceID) { voice in
                body(state.backend, voice)
            }
        }
    }

    private func restartVoices(
        for soundID: ResourceID,
        using sound: Backend.SoundResource,
        _ state: State
    ) {
        state.voices.removeAll { voice in
            guard voice.pointee.soundID == soundID else { return false }
            guard !voice.pointee.completion.isFinished else {
                state.backend.destroy(voice.pointee.resource)
                return true
            }

            state.backend.stop(voice.pointee.resource)
            state.backend.destroy(voice.pointee.resource)

            let busResource: Backend.BusResource?
            if let busID = voice.pointee.busID {
                guard let resource = state.buses.withValue(
                    for: busID,
                    { $0.pointee.resource }
                ) else {
                    return true
                }
                busResource = resource
            } else {
                busResource = nil
            }

            let completion = AudioCompletion()
            guard let resource = try? state.backend.play(
                sound,
                on: busResource,
                volume: voice.pointee.volume,
                pan: voice.pointee.pan,
                looping: voice.pointee.looping,
                rate: voice.pointee.rate,
                completion: completion
            ) else {
                return true
            }
            if voice.pointee.isPaused {
                state.backend.pause(resource)
            }
            voice.pointee.resource = resource
            voice.pointee.completion = completion
            return false
        }
    }

    private func stopVoices(
        for soundID: ResourceID,
        _ state: State
    ) {
        state.voices.removeAll { voice in
            guard voice.pointee.soundID == soundID else { return false }
            state.backend.stop(voice.pointee.resource)
            state.backend.destroy(voice.pointee.resource)
            return true
        }
    }

    private func reapFinishedVoices(_ state: State) {
        state.voices.removeAll { voice in
            guard voice.pointee.completion.isFinished
                    || state.backend.isFinished(voice.pointee.resource)
            else {
                return false
            }
            state.backend.destroy(voice.pointee.resource)
            return true
        }
    }

    private func disposeVoice(
        _ id: ResourceID,
        _ state: State
    ) {
        _ = state.voices.withValue(for: id) { voice in
            state.backend.destroy(voice.pointee.resource)
        }
        _ = state.voices.remove(id)
    }

    private func validate(
        _ samples: [Float],
        descriptor: SoundDescriptor
    ) throws(AudioError) {
        let expected = descriptor.sampleCount ?? .max
        guard samples.count == expected else {
            throw .invalidSampleCount(
                expected: expected,
                actual: samples.count
            )
        }
    }
}

private final class EngineSoundWriter<Backend: AudioBackend>: SoundWriter, @unchecked Sendable {
    private let engine: AudioEngine<Backend>
    private let sound: Sound

    init(engine: AudioEngine<Backend>, sound: Sound) {
        self.engine = engine
        self.sound = sound
    }

    func write(
        copying samples: [Float],
        descriptor: SoundDescriptor
    ) async throws(AudioError) {
        try engine.replace(
            sound,
            copying: samples,
            descriptor: descriptor
        )
    }

    func invalidate() async {
        engine.invalidate(sound)
    }
}

import PixlPlatformSynchronization
import Swift

package final class AudioEngine<Backend: AudioBackend>: AudioDevice, @unchecked Sendable {
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

    package func makeBus() -> Bus? {
        state.withLock { state in
            guard state.buses.count < state.buses.capacity,
                  let resource = state.backend.makeBus(),
                  let id = state.buses.insert(
                      BusRecord(resource: resource, volume: 1)
                  )
            else {
                return nil
            }
            return Bus(id: id)
        }
    }

    package func play(
        _ sound: Sound,
        on bus: Bus?,
        volume: Float,
        pan: Float,
        loop: Bool,
        rate: Float
    ) throws(AudioError) -> Playback {
        preconditionVolume(volume)
        preconditionPan(pan)
        preconditionRate(rate)

        return try state.withLock { state throws(AudioError) -> Playback in
            if state.voices.count == state.voices.capacity {
                reapFinishedVoices(state)
            }
            guard state.voices.count < state.voices.capacity else {
                throw .resourceCreationFailed(.voice)
            }

            guard let soundRecord = state.sounds.withValue(
                for: sound.id,
                { $0.pointee }
            ), let soundResource = soundRecord.resource else {
                throw .resourceUnavailable(.sound)
            }

            let busResource: Backend.BusResource?
            if let bus {
                guard let resource = state.buses.withValue(
                    for: bus.id,
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
                volume: volume,
                pan: pan,
                looping: loop,
                rate: rate,
                completion: completion
            )
            guard let id = state.voices.insert(
                VoiceRecord(
                    resource: resource,
                    completion: completion,
                    soundID: sound.id,
                    busID: bus?.id,
                    volume: volume,
                    pan: pan,
                    looping: loop,
                    rate: rate,
                    isPaused: false
                )
            ) else {
                state.backend.stop(resource)
                state.backend.destroy(resource)
                throw .resourceCreationFailed(.voice)
            }
            return Playback(id: id)
        }
    }

    package func pause(_ playback: Playback) {
        withLiveVoice(playback) { backend, voice in
            backend.pause(voice.pointee.resource)
            voice.pointee.isPaused = true
        }
    }

    package func resume(_ playback: Playback) {
        withLiveVoice(playback) { backend, voice in
            backend.resume(voice.pointee.resource)
            voice.pointee.isPaused = false
        }
    }

    package func stop(_ playback: Playback) {
        state.withLock { state in
            guard let _ = state.voices.withValue(
                for: playback.id,
                { voice in
                    state.backend.stop(voice.pointee.resource)
                    state.backend.destroy(voice.pointee.resource)
                }
            ) else {
                return
            }
            _ = state.voices.remove(playback.id)
        }
    }

    package subscript(volume playback: Playback) -> Float {
        get {
            withLiveVoice(playback) { _, voice in
                voice.pointee.volume
            } ?? 0
        }
        set {
            withLiveVoice(playback) { backend, voice in
                preconditionVolume(newValue)
                backend.setVolume(newValue, for: voice.pointee.resource)
                voice.pointee.volume = newValue
            }
        }
    }

    package subscript(pan playback: Playback) -> Float {
        get {
            withLiveVoice(playback) { _, voice in
                voice.pointee.pan
            } ?? 0
        }
        set {
            withLiveVoice(playback) { backend, voice in
                preconditionPan(newValue)
                backend.setPan(newValue, for: voice.pointee.resource)
                voice.pointee.pan = newValue
            }
        }
    }

    package subscript(rate playback: Playback) -> Float {
        get {
            withLiveVoice(playback) { _, voice in
                voice.pointee.rate
            } ?? 0
        }
        set {
            withLiveVoice(playback) { backend, voice in
                preconditionRate(newValue)
                backend.setRate(newValue, for: voice.pointee.resource)
                voice.pointee.rate = newValue
            }
        }
    }

    package subscript(volume bus: Bus) -> Float {
        get {
            state.withLock { state in
                state.buses.withValue(for: bus.id) { bus in
                    bus.pointee.volume
                } ?? 0
            }
        }
        set {
            state.withLock { state in
                _ = state.buses.update(bus.id) { bus in
                    preconditionVolume(newValue)
                    state.backend.setVolume(
                        newValue,
                        for: bus.pointee.resource
                    )
                    bus.pointee.volume = newValue
                }
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
        _ playback: Playback,
        _ body: (
            Backend,
            UnsafeMutablePointer<VoiceRecord>
        ) -> Result
    ) -> Result? {
        state.withLock { state -> Result? in
            guard let finished = state.voices.withValue(
                for: playback.id,
                {
                    $0.pointee.completion.isFinished
                        || state.backend.isFinished($0.pointee.resource)
                }
            ) else {
                return nil
            }
            if finished {
                disposeVoice(playback.id, state)
                return nil
            }
            return state.voices.update(playback.id) { voice in
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

private func preconditionVolume(_ volume: Float) {
    precondition(
        volume.isFinite && volume >= 0,
        "Audio volume must be greater than zero"
    )
}

private func preconditionPan(_ pan: Float) {
    precondition(
        pan.isFinite && pan >= -1 && pan <= 1,
        "Audio pan must be between minus one and one"
    )
}

private func preconditionRate(_ rate: Float) {
    precondition(
        rate.isFinite && rate >= 0,
        "Audio rate must be greater than zero"
    )
}

import PixlPlatformSynchronization
import Swift

package final class AudioEngine<Backend: AudioBackend>: AudioDevice, @unchecked Sendable {
    private struct VoiceRecord {
        let resource: Backend.VoiceResource
        let completion: AudioCompletion
    }

    private struct State {
        let backend: Backend
        let sounds: ResourcePool<Backend.SoundResource>
        let voices: ResourcePool<VoiceRecord>
        let buses: ResourcePool<Backend.BusResource>
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
                buses: ResourcePool(capacity: settings.maxBusCount)
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
                state.backend.destroy(bus.pointee)
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
            guard let id = state.sounds.insert(resource) else {
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
            _ = state.sounds.remove(sound.id)
        }
    }

    package func makeBus() -> Bus? {
        state.withLock { state in
            guard state.buses.count < state.buses.capacity,
                  let resource = state.backend.makeBus(),
                  let id = state.buses.insert(resource)
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
        looping: Bool,
        rate: Float
    ) -> Playback? {
        preconditionVolume(volume)
        preconditionPan(pan)
        preconditionRate(rate)

        return state.withLock { state in
            if state.voices.count == state.voices.capacity {
                reapFinishedVoices(state)
            }
            guard state.voices.count < state.voices.capacity else {
                return nil
            }

            return state.sounds.withValue(for: sound.id) { sound in
                let busResource: Backend.BusResource?
                if let bus {
                    guard let resource = state.buses.withValue(
                        for: bus.id,
                        { $0.pointee }
                    ) else {
                        return nil
                    }
                    busResource = resource
                } else {
                    busResource = nil
                }

                let completion = AudioCompletion()
                guard let resource = state.backend.play(
                    sound.pointee,
                    on: busResource,
                    volume: volume,
                    pan: pan,
                    looping: looping,
                    rate: rate,
                    completion: completion
                ) else {
                    return nil
                }
                guard let id = state.voices.insert(
                    VoiceRecord(
                        resource: resource,
                        completion: completion
                    )
                ) else {
                    state.backend.stop(resource)
                    state.backend.destroy(resource)
                    return nil
                }
                return Playback(id: id)
            } ?? nil
        }
    }

    package func pause(_ playback: Playback) {
        withLiveVoice(playback) { backend, voice in
            backend.pause(voice)
        }
    }

    package func resume(_ playback: Playback) {
        withLiveVoice(playback) { backend, voice in
            backend.resume(voice)
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

    package func setVolume(
        _ volume: Float,
        for playback: Playback
    ) {
        preconditionVolume(volume)
        withLiveVoice(playback) { backend, voice in
            backend.setVolume(volume, for: voice)
        }
    }

    package func setPan(
        _ pan: Float,
        for playback: Playback
    ) {
        preconditionPan(pan)
        withLiveVoice(playback) { backend, voice in
            backend.setPan(pan, for: voice)
        }
    }

    package func setRate(
        _ rate: Float,
        for playback: Playback
    ) {
        preconditionRate(rate)
        withLiveVoice(playback) { backend, voice in
            backend.setRate(rate, for: voice)
        }
    }

    package func setVolume(
        _ volume: Float,
        for bus: Bus
    ) {
        preconditionVolume(volume)
        state.withLock { state in
            _ = state.buses.withValue(for: bus.id) { bus in
                state.backend.setVolume(volume, for: bus.pointee)
            }
        }
    }

    package func setMasterVolume(_ volume: Float) {
        preconditionVolume(volume)
        state.withLock { state in
            state.backend.setMasterVolume(volume)
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
                sound.pointee = replacement
            }) != nil else {
                throw .resourceCreationFailed(.sound)
            }
        }
    }

    private func withLiveVoice(
        _ playback: Playback,
        _ body: (Backend, Backend.VoiceResource) -> Void
    ) {
        state.withLock { state in
            guard let finished = state.voices.withValue(
                for: playback.id,
                { $0.pointee.completion.isFinished }
            ) else {
                return
            }
            if finished {
                disposeVoice(playback.id, state)
                return
            }
            _ = state.voices.withValue(for: playback.id) { voice in
                body(state.backend, voice.pointee.resource)
            }
        }
    }

    private func reapFinishedVoices(_ state: State) {
        state.voices.removeAll { voice in
            guard voice.pointee.completion.isFinished else { return false }
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
}

private func preconditionVolume(_ volume: Float) {
    precondition(
        volume.isFinite && volume >= 0 && volume <= 1,
        "Audio volume must be between zero and one"
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
        rate.isFinite && rate >= 0.25 && rate <= 4,
        "Audio rate must be between 0.25 and 4"
    )
}

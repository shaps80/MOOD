import PixlPlatform
import Testing

private struct TestSound {
    let firstSample: Float
}

private final class TestBus {
    var volume: Float = 1
}

private final class TestVoice {
    let sound: TestSound
    let bus: TestBus?
    let completion: AudioCompletion
    var volume: Float
    var pan: Float
    let looping: Bool
    var rate: Float
    var isPaused = false
    var isStopped = false
    var isDestroyed = false
    var isBackendFinished = false

    init(
        sound: TestSound,
        bus: TestBus?,
        volume: Float,
        pan: Float,
        looping: Bool,
        rate: Float,
        completion: AudioCompletion
    ) {
        self.sound = sound
        self.bus = bus
        self.volume = volume
        self.pan = pan
        self.looping = looping
        self.rate = rate
        self.completion = completion
    }
}

private final class TestAudioBackend: AudioBackend {
    var voices: [TestVoice] = []
    var masterVolume: Float = 1

    func makeSound(
        copying samples: [Float],
        descriptor: SoundDescriptor
    ) throws(AudioError) -> TestSound {
        TestSound(firstSample: samples[0])
    }

    func makeBus() -> TestBus? {
        TestBus()
    }

    func destroy(_ bus: TestBus) {}

    func play(
        _ sound: TestSound,
        on bus: TestBus?,
        volume: Float,
        pan: Float,
        looping: Bool,
        rate: Float,
        completion: AudioCompletion
    ) throws(AudioError) -> TestVoice {
        let voice = TestVoice(
            sound: sound,
            bus: bus,
            volume: volume,
            pan: pan,
            looping: looping,
            rate: rate,
            completion: completion
        )
        voices.append(voice)
        return voice
    }

    func pause(_ voice: TestVoice) {
        voice.isPaused = true
    }

    func resume(_ voice: TestVoice) {
        voice.isPaused = false
    }

    func stop(_ voice: TestVoice) {
        voice.isStopped = true
    }

    func destroy(_ voice: TestVoice) {
        voice.isDestroyed = true
    }

    func isFinished(_ voice: TestVoice) -> Bool {
        voice.isBackendFinished
    }

    func setVolume(_ volume: Float, for voice: TestVoice) {
        voice.volume = volume
    }

    func setPan(_ pan: Float, for voice: TestVoice) {
        voice.pan = pan
    }

    func setRate(_ rate: Float, for voice: TestVoice) {
        voice.rate = rate
    }

    func setVolume(_ volume: Float, for bus: TestBus) {
        bus.volume = volume
    }

    func setMasterVolume(_ volume: Float) {
        masterVolume = volume
    }
}

private let testSoundDescriptor = SoundDescriptor(
    sampleRate: 44_100,
    channelLayout: .mono,
    frameCount: 1
)

@Suite("Audio engine")
struct AudioEngineTests {
    @Test
    func preparationIsSilentAndVoiceCapacityAppliesOnPlay() throws {
        let backend = TestAudioBackend()
        let audio = AudioEngine(
            backend: backend,
            settings: AudioSettings(
                maxSoundCount: 1,
                maxVoiceCount: 2,
                maxBusCount: 1
            )
        )
        let sound = try audio.makeSound(
            copying: [0],
            descriptor: testSoundDescriptor
        )

        #expect(throws: AudioError.self) {
            try audio.makeSound(
                copying: [1],
                descriptor: testSoundDescriptor
            )
        }
        _ = try audio.makeBus()
        #expect(throws: AudioError.self) {
            try audio.makeBus()
        }

        let first = audio.prepare(sound, on: audio.masterBus)
        let second = audio.prepare(sound, on: audio.masterBus)
        let third = audio.prepare(sound, on: audio.masterBus)

        #expect(backend.voices.isEmpty)
        try first.play()
        try second.play()
        #expect(backend.voices.count == 2)
        #expect(throws: AudioError.self) {
            try third.play()
        }

        backend.voices[0].completion.finish()
        try third.play()
        #expect(backend.voices[0].isDestroyed)
    }

    @Test
    func playbackAndBusOwnTheirControls() throws {
        let backend = TestAudioBackend()
        let audio = AudioEngine(
            backend: backend,
            settings: .default
        )
        let sound = try audio.makeSound(
            copying: [0],
            descriptor: testSoundDescriptor
        )
        let bus = try audio.makeBus()
        let playback = audio.prepare(sound, on: audio.masterBus)
        playback.bus = bus
        playback.volume = 0.8
        playback.pan = -0.25
        playback.rate = 0.5
        playback.loop = true

        try playback.play()
        let voice = backend.voices[0]

        #expect(voice.bus != nil)
        #expect(voice.volume == 0.8)
        #expect(voice.pan == -0.25)
        #expect(voice.rate == 0.5)
        #expect(voice.looping)

        playback.pause()
        #expect(voice.isPaused)
        try playback.play()
        #expect(!voice.isPaused)
        #expect(playback.volume == 0.8)
        #expect(playback.pan == -0.25)
        #expect(playback.rate == 0.5)
        #expect(bus.volume == 1)
        #expect(audio.masterVolume == 1)

        playback.volume = 0.4
        playback.pan = 0.5
        playback.rate = 2
        bus.volume = 0.6
        audio.masterBus.volume = 0.7

        #expect(voice.volume == 0.4)
        #expect(voice.pan == 0.5)
        #expect(voice.rate == 2)
        #expect(voice.bus?.volume == 0.6)
        #expect(backend.masterVolume == 0.7)
        #expect(playback.volume == 0.4)
        #expect(playback.pan == 0.5)
        #expect(playback.rate == 2)
        #expect(bus.volume == 0.6)
        #expect(audio.masterVolume == 0.7)

        playback.stop()
        #expect(voice.isStopped)
        #expect(voice.isDestroyed)

        try playback.play()
        #expect(backend.voices[1].volume == 0.4)
        #expect(backend.voices[1].pan == 0.5)
        #expect(backend.voices[1].rate == 2)
        #expect(backend.voices[1].looping)
    }

    @Test
    func reclaimsBackendFinishedVoiceOnCapacityPressure() throws {
        let backend = TestAudioBackend()
        let audio = AudioEngine(
            backend: backend,
            settings: AudioSettings(
                maxSoundCount: 1,
                maxVoiceCount: 1,
                maxBusCount: 1
            )
        )
        let sound = try audio.makeSound(
            copying: [0],
            descriptor: testSoundDescriptor
        )

        let playback = audio.prepare(sound, on: audio.masterBus)
        try playback.play()
        backend.voices[0].isBackendFinished = true

        try playback.play()
        #expect(backend.voices[0].isDestroyed)
        #expect(backend.voices.count == 2)
    }

    @Test
    func hotSwapRestartsExistingVoiceAndKeepsPlaybackHandle() async throws {
        let backend = TestAudioBackend()
        let audio = AudioEngine(
            backend: backend,
            settings: .default
        )
        let sound = try audio.makeSound(
            copying: [0.25],
            descriptor: testSoundDescriptor
        )
        let bus = try audio.makeBus()
        let playback = audio.prepare(sound, on: bus)
        playback.volume = 0.8
        playback.pan = -0.25
        playback.rate = 0.5
        playback.loop = true
        try playback.play()
        playback.pause()
        let writer = try #require(audio.soundWriter(for: sound))

        try await writer.write(
            copying: [0.75],
            descriptor: testSoundDescriptor
        )
        #expect(backend.voices[0].isStopped)
        #expect(backend.voices[0].isDestroyed)
        #expect(backend.voices[1].sound.firstSample == 0.75)
        #expect(backend.voices[1].bus === backend.voices[0].bus)
        #expect(backend.voices[1].volume == 0.8)
        #expect(backend.voices[1].pan == -0.25)
        #expect(backend.voices[1].rate == 0.5)
        #expect(backend.voices[1].looping)
        #expect(backend.voices[1].isPaused)

        playback.rate = 2
        #expect(backend.voices[1].rate == 2)
    }

    @Test
    func invalidationStopsVoicesUntilSoundIsReplaced() async throws {
        let backend = TestAudioBackend()
        let audio = AudioEngine(
            backend: backend,
            settings: .default
        )
        let sound = try audio.makeSound(
            copying: [0.25],
            descriptor: testSoundDescriptor
        )
        let playback = audio.prepare(sound, on: audio.masterBus)
        playback.volume = 0.6
        playback.loop = true
        try playback.play()
        let writer = try #require(audio.soundWriter(for: sound))

        await writer.invalidate()

        #expect(backend.voices[0].isStopped)
        #expect(backend.voices[0].isDestroyed)
        #expect(throws: AudioError.self) {
            try playback.play()
        }

        try await writer.write(
            copying: [0.75],
            descriptor: testSoundDescriptor
        )
        try playback.play()
        #expect(backend.voices[1].sound.firstSample == 0.75)
        #expect(backend.voices[1].volume == 0.6)
        #expect(backend.voices[1].looping)
    }
}

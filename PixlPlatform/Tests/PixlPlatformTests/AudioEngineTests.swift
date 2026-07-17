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
        rate: Float,
        completion: AudioCompletion
    ) {
        self.sound = sound
        self.bus = bus
        self.volume = volume
        self.pan = pan
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
    func enforcesCapacitiesAndReclaimsCompletedVoicesOnPressure() throws {
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
        #expect(audio.makeBus() != nil)
        #expect(audio.makeBus() == nil)

        let first = try audio.play(
            sound,
            on: nil,
            volume: 1,
            pan: 0,
            looping: false,
            rate: 1
        )
        let second = try audio.play(
            sound,
            on: nil,
            volume: 1,
            pan: 0,
            looping: false,
            rate: 1
        )
        _ = first
        _ = second
        #expect(throws: AudioError.self) {
            try audio.play(
                sound,
                on: nil,
                volume: 1,
                pan: 0,
                looping: false,
                rate: 1
            )
        }

        backend.voices[0].completion.finish()
        _ = try audio.play(
            sound,
            on: nil,
            volume: 1,
            pan: 0,
            looping: false,
            rate: 1
        )
        #expect(backend.voices[0].isDestroyed)
    }

    @Test
    func routesAndControlsVoicesAndBuses() throws {
        let backend = TestAudioBackend()
        let audio = AudioEngine(
            backend: backend,
            settings: .default
        )
        let sound = try audio.makeSound(
            copying: [0],
            descriptor: testSoundDescriptor
        )
        let bus = try #require(audio.makeBus())
        let playback = try audio.play(
            sound,
            on: bus,
            volume: 0.8,
            pan: -0.25,
            looping: false,
            rate: 0.5
        )
        let voice = backend.voices[0]

        #expect(voice.bus != nil)
        #expect(voice.volume == 0.8)
        #expect(voice.pan == -0.25)
        #expect(voice.rate == 0.5)

        audio.pause(playback)
        #expect(voice.isPaused)
        audio.resume(playback)
        #expect(!voice.isPaused)
        #expect(audio[volume: playback] == 0.8)
        #expect(audio[pan: playback] == -0.25)
        #expect(audio[rate: playback] == 0.5)
        #expect(audio[volume: bus] == 1)
        #expect(audio.masterVolume == 1)

        audio[volume: playback] = 0.4
        audio[pan: playback] = 0.5
        audio[rate: playback] = 2
        audio[volume: bus] = 0.6
        audio.masterVolume = 0.7

        #expect(voice.volume == 0.4)
        #expect(voice.pan == 0.5)
        #expect(voice.rate == 2)
        #expect(voice.bus?.volume == 0.6)
        #expect(backend.masterVolume == 0.7)
        #expect(audio[volume: playback] == 0.4)
        #expect(audio[pan: playback] == 0.5)
        #expect(audio[rate: playback] == 2)
        #expect(audio[volume: bus] == 0.6)
        #expect(audio.masterVolume == 0.7)

        audio.stop(playback)
        #expect(voice.isStopped)
        #expect(voice.isDestroyed)
        #expect(audio[volume: playback] == 0)
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

        _ = try audio.play(
            sound,
            on: nil,
            volume: 1,
            pan: 0,
            looping: false,
            rate: 1
        )
        backend.voices[0].isBackendFinished = true

        _ = try audio.play(
            sound,
            on: nil,
            volume: 1,
            pan: 0,
            looping: false,
            rate: 1
        )
        #expect(backend.voices[0].isDestroyed)
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
        let playback = try audio.play(
            sound,
            on: nil,
            volume: 1,
            pan: 0,
            looping: false,
            rate: 1
        )
        let writer = try #require(audio.soundWriter(for: sound))

        try await writer.write(
            copying: [0.75],
            descriptor: testSoundDescriptor
        )
        #expect(backend.voices[0].isStopped)
        #expect(backend.voices[0].isDestroyed)
        #expect(backend.voices[1].sound.firstSample == 0.75)

        audio[rate: playback] = 2
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
        _ = try audio.play(
            sound,
            on: nil,
            volume: 1,
            pan: 0,
            looping: false,
            rate: 1
        )
        let writer = try #require(audio.soundWriter(for: sound))

        await writer.invalidate()

        #expect(backend.voices[0].isStopped)
        #expect(backend.voices[0].isDestroyed)
        #expect(throws: AudioError.self) {
            try audio.play(
                sound,
                on: nil,
                volume: 1,
                pan: 0,
                looping: false,
                rate: 1
            )
        }

        try await writer.write(
            copying: [0.75],
            descriptor: testSoundDescriptor
        )
        _ = try audio.play(
            sound,
            on: nil,
            volume: 1,
            pan: 0,
            looping: false,
            rate: 1
        )
        #expect(backend.voices[1].sound.firstSample == 0.75)
    }
}

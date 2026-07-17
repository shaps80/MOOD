#if os(macOS)
@preconcurrency import AVFAudio
@testable import PixlMetalPlatform
@testable import PixlPlatform
import Testing

@Suite("Metal audio backend")
struct MetalAudioBackendTests {
    @Test
    func recoversStoppedEngineWithoutBlockingPlayback() async throws {
        let engine = AVAudioEngine()
        let backend = try #require(
            MetalAudioBackend(engine: engine)
        )
        let descriptor = SoundDescriptor(
            sampleRate: 44_100,
            channelLayout: .mono,
            frameCount: 1
        )
        let sound = try backend.makeSound(
            copying: [0],
            descriptor: descriptor
        )

        engine.stop()
        #expect(!engine.isRunning)

        let start = ContinuousClock.now
        let voice = try #require(
            backend.play(
                sound,
                on: nil,
                volume: 1,
                pan: 0,
                looping: false,
                rate: 1,
                completion: AudioCompletion()
            )
        )
        let elapsed = ContinuousClock.now - start

        #expect(elapsed < .milliseconds(50))
        try await waitUntilRunning(engine)
        #expect(engine.isRunning)
        backend.destroy(voice)
    }

    private func waitUntilRunning(
        _ engine: AVAudioEngine
    ) async throws {
        for _ in 0..<200 {
            guard !engine.isRunning else { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Audio engine did not recover within two seconds")
    }
}
#endif

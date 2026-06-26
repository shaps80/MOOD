@preconcurrency import AVFoundation
import Pixl
import Swift

@MainActor
final class Audio {
    private let assetResolver: AssetResolver
    private let engine = AVAudioEngine()
    private var soundPlayers: [SoundID: SoundPlayer] = [:]

    init(assetResolver: AssetResolver) {
        self.assetResolver = assetResolver
    }

    func loadSoundBuffers(_ soundAssets: [SoundAsset]) {
        for soundAsset in Set(soundAssets) {
            loadSoundBuffer(soundAsset)
        }

        prepareEngine()
    }

    func playSounds(_ sounds: [SoundID]) {
        guard !sounds.isEmpty else { return }

        startEngineIfNeeded()

        for sound in sounds {
            playSound(sound)
        }
    }

    private func loadSoundBuffer(_ soundAsset: SoundAsset) {
        guard let url = assetResolver.url(for: soundAsset.path) else {
            print("Unable to find sound asset '\(soundAsset.path)'")
            return
        }

        do {
            let file = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
            ) else {
                print("Unable to create sound buffer for '\(soundAsset.path)'")
                return
            }

            try file.read(into: buffer)

            let playerNode = AVAudioPlayerNode()
            engine.attach(playerNode)
            engine.connect(
                playerNode,
                to: engine.mainMixerNode,
                format: buffer.format
            )
            playerNode.prepare(withFrameCount: buffer.frameLength)

            soundPlayers[soundAsset.id] = SoundPlayer(
                buffer: buffer,
                playerNode: playerNode
            )
        } catch {
            print("Unable to load sound asset '\(soundAsset.path)': \(error)")
        }
    }

    private func playSound(_ sound: SoundID) {
        guard let soundPlayer = soundPlayers[sound] else {
            return
        }

        if soundPlayer.playerNode.isPlaying {
            soundPlayer.playerNode.stop()
        }

        soundPlayer.playerNode.scheduleBuffer(soundPlayer.buffer)
        soundPlayer.playerNode.play()
    }

    private func prepareEngine() {
        _ = engine.outputNode
        engine.prepare()
        startEngineIfNeeded()
    }

    private func startEngineIfNeeded() {
        guard !engine.isRunning else { return }

        do {
            try engine.start()
        } catch {
            print("Unable to start audio engine: \(error)")
        }
    }
}

private struct SoundPlayer {
    let buffer: AVAudioPCMBuffer
    let playerNode: AVAudioPlayerNode
}

@preconcurrency import AVFoundation
import GameCore
import Swift

@MainActor
final class Audio {
    private let assetResolver: AssetResolver
    private var soundData: [SoundID: Data] = [:]
    private var activePlayers: [AVAudioPlayer] = []

    init(assetResolver: AssetResolver) {
        self.assetResolver = assetResolver
    }

    func loadSoundBuffers(_ soundAssets: [SoundAsset]) {
        for soundAsset in Set(soundAssets) {
            loadSoundBuffer(soundAsset)
        }
    }

    func playSounds(_ sounds: [Sound]) {
        guard !sounds.isEmpty else { return }

        activePlayers.removeAll { !$0.isPlaying }

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
            soundData[soundAsset.id] = try Data(contentsOf: url)
        } catch {
            print("Unable to load sound asset '\(soundAsset.path)': \(error)")
        }
    }

    private func playSound(_ sound: Sound) {
        guard let data = soundData[sound.id] else {
            return
        }

        do {
            let player = try AVAudioPlayer(data: data)
            player.prepareToPlay()
            player.play()
            activePlayers.append(player)
        } catch {
            print("Unable to play sound '\(sound.id.rawValue)': \(error)")
        }
    }
}

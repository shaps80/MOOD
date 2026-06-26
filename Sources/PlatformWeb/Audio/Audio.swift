import GameCore
import JavaScriptKit
import Swift

final class Audio {
    private var audioContext: JSObject?
    private var soundBuffers: [SoundID: JSValue] = [:]
    private var soundLoadClosures: [JSClosure] = []

    func configure() {
        let global = JSObject.global
        guard let audioContextConstructor = global.AudioContext.object ?? global.webkitAudioContext.object else {
            _ = global.console.warn("Web Audio is not available")
            return
        }

        audioContext = audioContextConstructor.new()
    }

    func loadSoundBuffers(_ soundAssets: [SoundAsset]) {
        guard audioContext != nil else { return }

        for soundAsset in Set(soundAssets) {
            loadSoundBuffer(soundAsset)
        }
    }

    func playSounds(_ sounds: [Sound]) {
        guard !sounds.isEmpty else { return }

        resumeAudioContext()

        for sound in sounds {
            playSound(sound)
        }
    }

    private func loadSoundBuffer(_ soundAsset: SoundAsset) {
        let responseClosure = JSClosure { [weak self] arguments in
            guard let self,
                  let response = arguments.first?.object
            else {
                return .undefined
            }

            let decodeClosure = JSClosure { [weak self] arguments in
                guard let self,
                      let audioContext = self.audioContext,
                      let arrayBuffer = arguments.first
                else {
                    return .undefined
                }

                let bufferClosure = JSClosure { [weak self] arguments in
                    guard let buffer = arguments.first else { return .undefined }

                    self?.soundBuffers[soundAsset.id] = buffer
                    return .undefined
                }

                self.soundLoadClosures.append(bufferClosure)

                _ = audioContext.decodeAudioData!(arrayBuffer).then(bufferClosure)
                return .undefined
            }

            self.soundLoadClosures.append(decodeClosure)

            _ = response.arrayBuffer!().then(decodeClosure)
            return .undefined
        }

        let errorClosure = JSClosure { _ in
            _ = JSObject.global.console.error("Unable to load sound asset '\(soundAsset.path)'")
            return .undefined
        }

        soundLoadClosures.append(responseClosure)
        soundLoadClosures.append(errorClosure)

        _ = JSObject.global.fetch!(soundAsset.path).then(responseClosure).catch(errorClosure)
    }

    private func playSound(_ sound: Sound) {
        guard let audioContext,
              let buffer = soundBuffers[sound.id],
              let source = audioContext.createBufferSource!().object
        else {
            return
        }

        source.buffer = buffer
        _ = source.connect!(audioContext.destination)
        _ = source.start!()
    }

    private func resumeAudioContext() {
        guard let audioContext,
              audioContext.state.string == "suspended"
        else {
            return
        }

        _ = audioContext.resume!()
    }
}

import Pixl

struct AudioSettings: Codable {
    var master: Float = 1
    var music: Float = 0.8
    var effects: Float = 0.1
    var voices: Float = 1
}

final class GameAudio {
    let music: Bus
    let effects: Bus
    let voices: Bus

    init(
        audio: Audio,
        settings: AudioSettings
    ) throws {
        music = try audio.makeBus()
        effects = try audio.makeBus()
        voices = try audio.makeBus()

        audio.masterVolume = settings.master
        music.volume = settings.music
        effects.volume = settings.effects
        voices.volume = settings.voices
    }

    func settings(audio: Audio) -> AudioSettings {
        AudioSettings(
            master: audio.masterVolume,
            music: music.volume,
            effects: effects.volume,
            voices: voices.volume
        )
    }
}

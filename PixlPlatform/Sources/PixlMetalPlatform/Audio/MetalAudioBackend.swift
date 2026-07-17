#if os(macOS)
@preconcurrency import AVFAudio
import PixlPlatform
import Swift

package final class MetalSoundResource {
    let buffer: AVAudioPCMBuffer

    init(buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }
}

package final class MetalBusResource {
    let mixer: AVAudioMixerNode

    init(mixer: AVAudioMixerNode) {
        self.mixer = mixer
    }
}

package final class MetalVoiceResource {
    let player: AVAudioPlayerNode
    let varispeed: AVAudioUnitVarispeed
    let sound: MetalSoundResource

    init(
        player: AVAudioPlayerNode,
        varispeed: AVAudioUnitVarispeed,
        sound: MetalSoundResource
    ) {
        self.player = player
        self.varispeed = varispeed
        self.sound = sound
    }
}

package final class MetalAudioBackend: AudioBackend {
    private let engine = AVAudioEngine()

    package init?() {
        _ = engine.mainMixerNode
        engine.prepare()
        do {
            try engine.start()
        } catch {
            return nil
        }
    }

    deinit {
        engine.stop()
    }

    package func makeSound(
        copying samples: [Float],
        descriptor: SoundDescriptor
    ) throws(AudioError) -> MetalSoundResource {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(descriptor.sampleRate),
            channels: AVAudioChannelCount(
                descriptor.channelLayout.channelCount
            ),
            interleaved: false
        ),
        let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(descriptor.frameCount)
        ),
        let channels = buffer.floatChannelData
        else {
            throw .resourceCreationFailed(.sound)
        }

        buffer.frameLength = AVAudioFrameCount(descriptor.frameCount)
        samples.withUnsafeBufferPointer { source in
            let frameCount = Int(descriptor.frameCount)
            var channel = 0
            while channel < Int(descriptor.channelLayout.channelCount) {
                channels[channel].update(
                    from: source.baseAddress!.advanced(
                        by: channel * frameCount
                    ),
                    count: frameCount
                )
                channel += 1
            }
        }
        return MetalSoundResource(buffer: buffer)
    }

    package func makeBus() -> MetalBusResource? {
        let mixer = AVAudioMixerNode()
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
        return MetalBusResource(mixer: mixer)
    }

    package func destroy(_ bus: MetalBusResource) {
        engine.disconnectNodeOutput(bus.mixer)
        engine.detach(bus.mixer)
    }

    package func play(
        _ sound: MetalSoundResource,
        on bus: MetalBusResource?,
        volume: Float,
        pan: Float,
        looping: Bool,
        rate: Float,
        completion: AudioCompletion
    ) -> MetalVoiceResource? {
        let player = AVAudioPlayerNode()
        let varispeed = AVAudioUnitVarispeed()
        engine.attach(player)
        engine.attach(varispeed)
        engine.connect(
            player,
            to: varispeed,
            format: sound.buffer.format
        )
        engine.connect(
            varispeed,
            to: bus?.mixer ?? engine.mainMixerNode,
            format: sound.buffer.format
        )

        player.volume = volume
        player.pan = pan
        varispeed.rate = rate
        player.scheduleBuffer(
            sound.buffer,
            at: nil,
            options: looping ? [.loops] : [],
            completionCallbackType: .dataPlayedBack
        ) { _ in
            completion.finish()
        }
        player.play()

        return MetalVoiceResource(
            player: player,
            varispeed: varispeed,
            sound: sound
        )
    }

    package func pause(_ voice: MetalVoiceResource) {
        voice.player.pause()
    }

    package func resume(_ voice: MetalVoiceResource) {
        voice.player.play()
    }

    package func stop(_ voice: MetalVoiceResource) {
        voice.player.stop()
    }

    package func destroy(_ voice: MetalVoiceResource) {
        voice.player.stop()
        engine.disconnectNodeOutput(voice.player)
        engine.disconnectNodeOutput(voice.varispeed)
        engine.detach(voice.player)
        engine.detach(voice.varispeed)
    }

    package func setVolume(
        _ volume: Float,
        for voice: MetalVoiceResource
    ) {
        voice.player.volume = volume
    }

    package func setPan(
        _ pan: Float,
        for voice: MetalVoiceResource
    ) {
        voice.player.pan = pan
    }

    package func setRate(
        _ rate: Float,
        for voice: MetalVoiceResource
    ) {
        voice.varispeed.rate = rate
    }

    package func setVolume(
        _ volume: Float,
        for bus: MetalBusResource
    ) {
        bus.mixer.outputVolume = volume
    }

    package func setMasterVolume(_ volume: Float) {
        engine.mainMixerNode.outputVolume = volume
    }
}
#endif

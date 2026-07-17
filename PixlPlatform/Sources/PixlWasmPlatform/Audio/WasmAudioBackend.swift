import JavaScriptKit
import PixlPlatform
import Swift

package final class WasmSoundResource {
    let buffer: JSObject

    init(buffer: JSObject) {
        self.buffer = buffer
    }
}

package final class WasmBusResource {
    let gain: JSObject

    init(gain: JSObject) {
        self.gain = gain
    }
}

package final class WasmVoiceResource {
    private let context: JSObject
    private let sound: WasmSoundResource
    private let gain: JSObject
    private let panner: JSObject
    private let target: JSObject
    private let completion: AudioCompletion
    private let looping: Bool

    private var source: JSObject?
    private var ended: JSClosure?
    private var offset = 0.0
    private var anchor = 0.0
    private var rate: Float
    private var paused = false

    init(
        context: JSObject,
        sound: WasmSoundResource,
        target: JSObject,
        volume: Float,
        pan: Float,
        looping: Bool,
        rate: Float,
        completion: AudioCompletion
    ) {
        self.context = context
        self.sound = sound
        self.target = target
        self.completion = completion
        self.looping = looping
        self.rate = rate
        gain = context.createGain!().object!
        panner = context.createStereoPanner!().object!
        gain.gain.object!.value = .number(Double(volume))
        panner.pan.object!.value = .number(Double(pan))
        _ = gain.connect!(panner)
        _ = panner.connect!(target)
        start()
    }

    func pause() {
        guard !paused, source != nil else { return }
        advanceOffset()
        paused = true
        releaseSource(stopping: true)
    }

    func resume() {
        guard paused else { return }
        paused = false
        if !looping, offset >= duration {
            completion.finish()
            return
        }
        start()
    }

    func stop() {
        releaseSource(stopping: true)
    }

    func destroy() {
        releaseSource(stopping: true)
        _ = gain.disconnect!()
        _ = panner.disconnect!()
    }

    func setVolume(_ volume: Float) {
        gain.gain.object!.value = .number(Double(volume))
    }

    func setPan(_ pan: Float) {
        panner.pan.object!.value = .number(Double(pan))
    }

    func setRate(_ rate: Float) {
        advanceOffset()
        self.rate = rate
        source?.playbackRate.object?.value = .number(Double(rate))
    }

    private var duration: Double {
        sound.buffer.duration.number ?? 0
    }

    private func start() {
        guard duration > 0,
              let source = context.createBufferSource!().object
        else {
            completion.finish()
            return
        }

        source.buffer = .object(sound.buffer)
        source.loop = .boolean(looping)
        source.playbackRate.object!.value = .number(Double(rate))
        _ = source.connect!(gain)

        let ended = JSClosure { [completion] _ in
            completion.finish()
            return .undefined
        }
        source.onended = .object(ended)
        anchor = context.currentTime.number ?? 0
        _ = source.start!(0, offset)

        self.source = source
        self.ended = ended
    }

    private func advanceOffset() {
        guard source != nil, !paused else { return }
        let now = context.currentTime.number ?? anchor
        offset += max(0, now - anchor) * Double(rate)
        if looping, duration > 0 {
            offset.formTruncatingRemainder(dividingBy: duration)
        } else {
            offset = min(offset, duration)
        }
        anchor = now
    }

    private func releaseSource(stopping: Bool) {
        guard let source else { return }
        source.onended = .null
        if stopping {
            _ = source.stop!()
        }
        _ = source.disconnect!()
        self.source = nil
        ended = nil
    }
}

package final class WasmAudioBackend: AudioBackend {
    private let context: JSObject
    private let master: JSObject
    private var unlockClosures: [String: JSClosure] = [:]

    package init?() {
        let global = JSObject.global
        guard let constructor = global.AudioContext.object
            ?? global.webkitAudioContext.object
        else {
            return nil
        }
        let context = constructor.new()
        guard let master = context.createGain!().object,
              let destination = context.destination.object
        else {
            return nil
        }
        self.context = context
        self.master = master
        _ = master.connect!(destination)
        installUnlockListeners()
    }

    deinit {
        removeUnlockListeners()
        _ = master.disconnect!()
        _ = context.close!()
    }

    package func makeSound(
        copying samples: [Float],
        descriptor: SoundDescriptor
    ) throws(AudioError) -> WasmSoundResource {
        guard let buffer = context.createBuffer!(
            Int(descriptor.channelLayout.channelCount),
            Int(descriptor.frameCount),
            Int(descriptor.sampleRate)
        ).object else {
            throw .resourceCreationFailed(.sound)
        }

        samples.withUnsafeBufferPointer { source in
            let frameCount = Int(descriptor.frameCount)
            var channel = 0
            while channel < Int(descriptor.channelLayout.channelCount) {
                let channelSamples = UnsafeBufferPointer(
                    start: source.baseAddress!.advanced(
                        by: channel * frameCount
                    ),
                    count: frameCount
                )
                let typed = JSFloat32Array(buffer: channelSamples)
                _ = buffer.copyToChannel!(typed.jsObject, channel)
                channel += 1
            }
        }
        return WasmSoundResource(buffer: buffer)
    }

    package func makeBus() -> WasmBusResource? {
        guard let gain = context.createGain!().object else { return nil }
        _ = gain.connect!(master)
        return WasmBusResource(gain: gain)
    }

    package func destroy(_ bus: WasmBusResource) {
        _ = bus.gain.disconnect!()
    }

    package func play(
        _ sound: WasmSoundResource,
        on bus: WasmBusResource?,
        volume: Float,
        pan: Float,
        looping: Bool,
        rate: Float,
        completion: AudioCompletion
    ) -> WasmVoiceResource? {
        guard context.state.string == "running" else { return nil }
        return WasmVoiceResource(
            context: context,
            sound: sound,
            target: bus?.gain ?? master,
            volume: volume,
            pan: pan,
            looping: looping,
            rate: rate,
            completion: completion
        )
    }

    package func pause(_ voice: WasmVoiceResource) {
        voice.pause()
    }

    package func resume(_ voice: WasmVoiceResource) {
        voice.resume()
    }

    package func stop(_ voice: WasmVoiceResource) {
        voice.stop()
    }

    package func destroy(_ voice: WasmVoiceResource) {
        voice.destroy()
    }

    package func setVolume(
        _ volume: Float,
        for voice: WasmVoiceResource
    ) {
        voice.setVolume(volume)
    }

    package func setPan(
        _ pan: Float,
        for voice: WasmVoiceResource
    ) {
        voice.setPan(pan)
    }

    package func setRate(
        _ rate: Float,
        for voice: WasmVoiceResource
    ) {
        voice.setRate(rate)
    }

    package func setVolume(
        _ volume: Float,
        for bus: WasmBusResource
    ) {
        bus.gain.gain.object!.value = .number(Double(volume))
    }

    package func setMasterVolume(_ volume: Float) {
        master.gain.object!.value = .number(Double(volume))
    }

    private func installUnlockListeners() {
        let document = JSObject.global.document
        for event in ["pointerdown", "keydown", "touchstart"] {
            let closure = JSClosure { [weak self] _ in
                guard let self else { return .undefined }
                _ = self.context.resume!()
                self.removeUnlockListeners()
                return .undefined
            }
            unlockClosures[event] = closure
            _ = document.addEventListener(event, closure)
        }
    }

    private func removeUnlockListeners() {
        let document = JSObject.global.document
        for (event, closure) in unlockClosures {
            _ = document.removeEventListener(event, closure)
        }
        unlockClosures.removeAll(keepingCapacity: true)
    }
}

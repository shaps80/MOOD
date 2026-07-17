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

    private var source: JSObject?
    private var ended: JSClosure?
    private var contextStateChanged: JSClosure?
    private var timeline: PlaybackTimeline
    private var finished = false

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
        timeline = PlaybackTimeline(
            duration: max(
                sound.buffer.duration.number ?? 0,
                Double.leastNonzeroMagnitude
            ),
            looping: looping,
            rate: rate,
            at: Self.now
        )
        gain = context.createGain!().object!
        panner = context.createStereoPanner!().object!
        gain.gain.object!.value = .number(Double(volume))
        panner.pan.object!.value = .number(Double(pan))
        _ = gain.connect!(panner)
        _ = panner.connect!(target)
        installContextStateListener()
        synchronizeOutput()
    }

    func pause() {
        guard !isFinished() else { return }
        timeline.pause(at: Self.now)
        releaseSource(stopping: true)
    }

    func resume() {
        guard !isFinished() else { return }
        timeline.resume(at: Self.now)
        synchronizeOutput()
    }

    func stop() {
        timeline.stop()
        finished = true
        releaseSource(stopping: true)
    }

    func destroy() {
        removeContextStateListener()
        timeline.stop()
        finished = true
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
        guard !isFinished() else { return }
        timeline.setRate(rate, at: Self.now)
        source?.playbackRate.object?.value = .number(Double(rate))
    }

    func isFinished() -> Bool {
        guard !finished else { return true }
        guard timeline.currentOffset(at: Self.now) != nil else {
            complete()
            releaseSource(stopping: true)
            return true
        }
        return false
    }

    private func synchronizeOutput() {
        guard !finished, !timeline.isPaused else {
            releaseSource(stopping: true)
            return
        }
        guard context.state.string == "running" else {
            releaseSource(stopping: true)
            return
        }
        guard source == nil else { return }
        guard let offset = timeline.currentOffset(at: Self.now) else {
            complete()
            return
        }
        start(at: offset)
    }

    private func start(at offset: Double) {
        guard let source = context.createBufferSource!().object else {
            complete()
            return
        }

        source.buffer = .object(sound.buffer)
        source.loop = .boolean(timeline.looping)
        source.playbackRate.object!.value = .number(Double(timeline.rate))
        _ = source.connect!(gain)

        let ended = JSClosure { [weak self] _ in
            self?.sourceEnded()
            return .undefined
        }
        source.onended = .object(ended)

        self.source = source
        self.ended = ended
        _ = source.start!(0, offset)
    }

    private func sourceEnded() {
        guard let source else { return }
        source.onended = .null
        _ = source.disconnect!()
        self.source = nil
        ended = nil
        complete()
    }

    private func complete() {
        guard !finished else { return }
        finished = true
        timeline.stop()
        completion.finish()
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

    private func installContextStateListener() {
        let closure = JSClosure { [weak self] _ in
            self?.synchronizeOutput()
            return .undefined
        }
        contextStateChanged = closure
        _ = context.addEventListener!("statechange", closure)
    }

    private func removeContextStateListener() {
        guard let contextStateChanged else { return }
        _ = context.removeEventListener!("statechange", contextStateChanged)
        self.contextStateChanged = nil
    }

    private static var now: Double {
        (JSObject.global.performance.now().number ?? 0) * 0.001
    }
}

package final class WasmAudioBackend: AudioBackend {
    private let context: JSObject
    private let master: JSObject
    private var unlockClosures: [String: JSClosure] = [:]
    private var contextStateChanged: JSClosure?

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
        installContextStateListener()
    }

    deinit {
        removeUnlockListeners()
        removeContextStateListener()
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

    package func isFinished(_ voice: WasmVoiceResource) -> Bool {
        voice.isFinished()
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
        guard unlockClosures.isEmpty else { return }
        let document = JSObject.global.document
        for event in ["pointerdown", "keydown", "touchstart"] {
            let closure = JSClosure { [weak self] _ in
                guard let self else { return .undefined }
                _ = self.context.resume!()
                if self.context.state.string == "running" {
                    self.removeUnlockListeners()
                }
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

    private func installContextStateListener() {
        let closure = JSClosure { [weak self] _ in
            guard let self else { return .undefined }
            if self.context.state.string == "running" {
                self.removeUnlockListeners()
            } else {
                self.installUnlockListeners()
            }
            return .undefined
        }
        contextStateChanged = closure
        _ = context.addEventListener!("statechange", closure)
    }

    private func removeContextStateListener() {
        guard let contextStateChanged else { return }
        _ = context.removeEventListener!("statechange", contextStateChanged)
        self.contextStateChanged = nil
    }
}

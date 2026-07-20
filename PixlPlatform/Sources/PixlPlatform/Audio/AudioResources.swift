import Swift

/// An opaque handle to resident audio sample data.
///
/// Sounds are created and explicitly destroyed by their ``AudioDevice``.
public struct Sound: Hashable, Sendable {
    package let id: ResourceID

    package init(id: ResourceID) {
        self.id = id
    }
}

package protocol AudioController: AnyObject {
    func play(_ playback: Playback) throws(AudioError)
    func pause(_ playback: Playback)
    func stop(_ playback: Playback)
    func setVolume(for playback: Playback)
    func setPan(for playback: Playback)
    func setRate(for playback: Playback)
    func volume(for bus: Bus) -> Float
    func setVolume(_ volume: Float, for bus: Bus)
}

/// Reusable controls and settings for playing one sound on one bus.
///
/// Calling ``play()`` resumes a paused voice or starts a new voice after a stop
/// or natural completion. Releasing the playback stops its active voice.
public final class Playback: Hashable {
    package let controller: any AudioController
    package let sound: Sound
    package var voiceID: ResourceID?

    private var storedVolume: Float = 1
    private var storedPan: Float = 0
    private var storedRate: Float = 1
    private var storedBus: Bus

    package init(
        controller: any AudioController,
        sound: Sound,
        bus: Bus
    ) {
        precondition(
            ObjectIdentifier(controller)
                == ObjectIdentifier(bus.controller),
            "Playback and bus must belong to the same audio device"
        )
        self.controller = controller
        self.sound = sound
        storedBus = bus
    }

    deinit {
        controller.stop(self)
    }

    /// Starts or resumes playback with the current settings.
    /// - Throws: ``AudioError`` when the sound or bus is unavailable, or a voice cannot be created.
    public func play() throws(AudioError) {
        try controller.play(self)
    }

    /// Pauses the active voice while preserving its playback position.
    public func pause() {
        controller.pause(self)
    }

    /// Stops and releases the active voice.
    public func stop() {
        controller.stop(self)
    }

    /// Nonnegative linear gain applied to this playback.
    public var volume: Float {
        get { storedVolume }
        set {
            preconditionVolume(newValue)
            storedVolume = newValue
            controller.setVolume(for: self)
        }
    }

    /// Stereo position from `-1` (left) through `0` (centre) to `1` (right).
    public var pan: Float {
        get { storedPan }
        set {
            preconditionPan(newValue)
            storedPan = newValue
            controller.setPan(for: self)
        }
    }

    /// Nonnegative playback-rate multiplier. `0` holds the current position.
    public var rate: Float {
        get { storedRate }
        set {
            preconditionRate(newValue)
            storedRate = newValue
            controller.setRate(for: self)
        }
    }

    /// Mixing bus receiving this playback.
    public var bus: Bus {
        get { storedBus }
        set {
            precondition(
                ObjectIdentifier(controller)
                    == ObjectIdentifier(newValue.controller),
                "Playback and bus must belong to the same audio device"
            )
            storedBus = newValue
        }
    }

    /// Whether a newly started voice repeats after reaching the sound's end.
    public var loop = false

    /// Compares playback object identity.
    /// - Parameters:
    ///   - lhs: First playback.
    ///   - rhs: Second playback.
    /// - Returns: `true` only when both references identify the same object.
    public static func == (
        lhs: Playback,
        rhs: Playback
    ) -> Bool {
        lhs === rhs
    }

    /// Hashes playback object identity.
    /// - Parameter hasher: Hasher receiving this playback's identity.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

/// A flat audio mixing destination with independent volume.
public final class Bus: Hashable {
    package let controller: any AudioController
    package let id: ResourceID?

    package init(
        controller: any AudioController,
        id: ResourceID?
    ) {
        self.controller = controller
        self.id = id
    }

    /// Nonnegative linear gain applied to all playbacks routed through this bus.
    public var volume: Float {
        get {
            controller.volume(for: self)
        }
        set {
            preconditionVolume(newValue)
            controller.setVolume(newValue, for: self)
        }
    }

    /// Compares device and bus identity.
    /// - Parameters:
    ///   - lhs: First bus.
    ///   - rhs: Second bus.
    /// - Returns: `true` when both values represent the same bus on the same device.
    public static func == (
        lhs: Bus,
        rhs: Bus
    ) -> Bool {
        ObjectIdentifier(lhs.controller)
            == ObjectIdentifier(rhs.controller)
            && lhs.id == rhs.id
    }

    /// Hashes device and bus identity.
    /// - Parameter hasher: Hasher receiving this bus's identity.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(controller))
        hasher.combine(id)
    }
}

package func preconditionVolume(_ volume: Float) {
    precondition(
        volume.isFinite && volume >= 0,
        "Audio volume must be greater than or equal to zero"
    )
}

package func preconditionPan(_ pan: Float) {
    precondition(
        pan.isFinite && pan >= -1 && pan <= 1,
        "Audio pan must be between minus one and one"
    )
}

package func preconditionRate(_ rate: Float) {
    precondition(
        rate.isFinite && rate >= 0,
        "Audio rate must be greater than or equal to zero"
    )
}

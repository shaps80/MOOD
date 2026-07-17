import Swift

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

    public func play() throws(AudioError) {
        try controller.play(self)
    }

    public func pause() {
        controller.pause(self)
    }

    public func stop() {
        controller.stop(self)
    }

    public var volume: Float {
        get { storedVolume }
        set {
            preconditionVolume(newValue)
            storedVolume = newValue
            controller.setVolume(for: self)
        }
    }

    public var pan: Float {
        get { storedPan }
        set {
            preconditionPan(newValue)
            storedPan = newValue
            controller.setPan(for: self)
        }
    }

    public var rate: Float {
        get { storedRate }
        set {
            preconditionRate(newValue)
            storedRate = newValue
            controller.setRate(for: self)
        }
    }

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

    public var loop = false

    public static func == (
        lhs: Playback,
        rhs: Playback
    ) -> Bool {
        lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

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

    public var volume: Float {
        get {
            controller.volume(for: self)
        }
        set {
            preconditionVolume(newValue)
            controller.setVolume(newValue, for: self)
        }
    }

    public static func == (
        lhs: Bus,
        rhs: Bus
    ) -> Bool {
        ObjectIdentifier(lhs.controller)
            == ObjectIdentifier(rhs.controller)
            && lhs.id == rhs.id
    }

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

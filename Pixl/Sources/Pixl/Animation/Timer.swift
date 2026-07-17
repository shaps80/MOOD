import Swift

public struct Timer {
    public let duration: Double
    public private(set) var elapsed: Double = .zero

    public init(duration: Double) {
        assert(duration >= 0)
        self.duration = duration
    }

    public var progress: Double {
        duration == 0 ? 1 : min(elapsed / duration, 1)
    }

    public var isFinished: Bool {
        elapsed >= duration
    }

    public mutating func advance(by delta: Double) {
        elapsed = min(elapsed + delta, duration)
    }

    public mutating func invalidate() {
        elapsed = 0
    }
}

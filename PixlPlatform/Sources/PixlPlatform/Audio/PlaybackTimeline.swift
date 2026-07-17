import Swift

package struct PlaybackTimeline {
    private let duration: Double
    package let looping: Bool
    private var storedOffset = 0.0
    private var anchor: Double
    private(set) package var rate: Float
    private(set) package var isPaused = false
    private(set) package var isFinished = false

    package init(
        duration: Double,
        looping: Bool,
        rate: Float,
        at now: Double
    ) {
        precondition(duration.isFinite && duration > 0)
        precondition(rate.isFinite && rate >= 0)
        precondition(now.isFinite)

        self.duration = duration
        self.looping = looping
        self.rate = rate
        anchor = now
    }

    package mutating func currentOffset(at now: Double) -> Double? {
        guard !isFinished else { return nil }
        guard !isPaused else { return storedOffset }

        let elapsed = max(0, now - anchor) * Double(rate)
        let offset = storedOffset + elapsed
        if looping {
            return offset.truncatingRemainder(dividingBy: duration)
        }
        guard offset < duration else {
            storedOffset = duration
            isFinished = true
            return nil
        }
        return offset
    }

    package mutating func pause(at now: Double) {
        guard !isPaused, let offset = currentOffset(at: now) else { return }
        storedOffset = offset
        anchor = now
        isPaused = true
    }

    package mutating func resume(at now: Double) {
        guard isPaused, !isFinished else { return }
        anchor = now
        isPaused = false
    }

    package mutating func stop() {
        isFinished = true
    }

    package mutating func setRate(_ rate: Float, at now: Double) {
        precondition(rate.isFinite && rate >= 0)
        guard !isFinished else { return }
        if !isPaused {
            guard let offset = currentOffset(at: now) else { return }
            storedOffset = offset
            anchor = now
        }
        self.rate = rate
    }
}

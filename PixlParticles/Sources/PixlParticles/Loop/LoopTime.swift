import Swift

struct FixedTime: Hashable, Sendable {
    let tickIndex: UInt64
    let delta: Double
    let elapsedSeconds: Double

    init(
        tickIndex: UInt64,
        delta: Double,
        elapsedSeconds: Double
    ) {
        self.tickIndex = tickIndex
        self.delta = delta
        self.elapsedSeconds = elapsedSeconds
    }
}

struct UpdateTime: Hashable, Sendable {
    let frameIndex: UInt64
    let delta: Double
    let unscaledDelta: Double
    let elapsedSeconds: Double

    init(
        frameIndex: UInt64,
        delta: Double,
        unscaledDelta: Double,
        elapsedSeconds: Double
    ) {
        self.frameIndex = frameIndex
        self.delta = delta
        self.unscaledDelta = unscaledDelta
        self.elapsedSeconds = elapsedSeconds
    }
}

struct RenderTime: Hashable, Sendable {
    let frameIndex: UInt64
    let interpolation: Double

    init(
        frameIndex: UInt64,
        interpolation: Double
    ) {
        self.frameIndex = frameIndex
        self.interpolation = interpolation
    }
}

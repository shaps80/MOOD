import Swift

public struct FixedTime: Hashable, Sendable {
    public let tickIndex: UInt64
    public let deltaSeconds: Double
    public let elapsedSeconds: Double

    init(
        tickIndex: UInt64,
        deltaSeconds: Double,
        elapsedSeconds: Double
    ) {
        self.tickIndex = tickIndex
        self.deltaSeconds = deltaSeconds
        self.elapsedSeconds = elapsedSeconds
    }
}

public struct UpdateTime: Hashable, Sendable {
    public let frameIndex: UInt64
    public let deltaSeconds: Double
    public let elapsedSeconds: Double

    init(
        frameIndex: UInt64,
        deltaSeconds: Double,
        elapsedSeconds: Double
    ) {
        self.frameIndex = frameIndex
        self.deltaSeconds = deltaSeconds
        self.elapsedSeconds = elapsedSeconds
    }
}

public struct RenderTime: Hashable, Sendable {
    public let frameIndex: UInt64
    public let interpolation: Double

    init(frameIndex: UInt64, interpolation: Double) {
        self.frameIndex = frameIndex
        self.interpolation = interpolation
    }
}

import Swift

public struct FixedStep: Hashable, Sendable {
    public let updatesPerSecond: UInt32
    public let maximumUpdatesPerFrame: UInt32

    public init(
        updatesPerSecond: UInt32,
        maximumUpdatesPerFrame: UInt32
    ) {
        precondition(updatesPerSecond > 0)
        precondition(maximumUpdatesPerFrame > 0)

        self.updatesPerSecond = updatesPerSecond
        self.maximumUpdatesPerFrame = maximumUpdatesPerFrame
    }
}

public struct LoopSettings: Hashable, Sendable {
    public let maximumDeltaSeconds: Double
    public let fixedStep: FixedStep?

    public init(
        maximumDeltaSeconds: Double = 0.25,
        fixedStep: FixedStep? = FixedStep(
            updatesPerSecond: 60,
            maximumUpdatesPerFrame: 8
        )
    ) {
        precondition(maximumDeltaSeconds.isFinite)
        precondition(maximumDeltaSeconds > 0)

        self.maximumDeltaSeconds = maximumDeltaSeconds
        self.fixedStep = fixedStep
    }

    public static let `default` = Self()
}

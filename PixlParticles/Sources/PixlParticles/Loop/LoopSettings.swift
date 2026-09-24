import Swift

struct FixedStep: Hashable, Sendable {
    let updatesPerSecond: UInt32
    let maximumUpdatesPerFrame: UInt32

    init(
        updatesPerSecond: UInt32,
        maximumUpdatesPerFrame: UInt32
    ) {
        precondition(updatesPerSecond > 0)
        precondition(maximumUpdatesPerFrame > 0)

        self.updatesPerSecond = updatesPerSecond
        self.maximumUpdatesPerFrame = maximumUpdatesPerFrame
    }
}

struct LoopSettings: Hashable, Sendable {
    let maximumDeltaSeconds: Double
    let fixedStep: FixedStep?

    init(
        maximumDeltaSeconds: Double = 0.25,
        fixedStep: FixedStep? = FixedStep(
            updatesPerSecond: 30,
            maximumUpdatesPerFrame: 4
        )
    ) {
        precondition(maximumDeltaSeconds.isFinite)
        precondition(maximumDeltaSeconds > 0)

        self.maximumDeltaSeconds = maximumDeltaSeconds
        self.fixedStep = fixedStep
    }

    static let `default` = Self()
}

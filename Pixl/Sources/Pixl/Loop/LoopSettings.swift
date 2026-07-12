import Swift

/// Fixed-rate simulation policy.
///
/// The runtime accumulates elapsed presentation time and invokes
/// ``Game/fixedUpdate(_:lanes:)`` at this cadence. Rendering remains driven by
/// presentation callbacks and can run at a different rate.
public struct FixedStep: Hashable, Sendable {
    /// Number of fixed simulation ticks per second.
    public let updatesPerSecond: UInt32

    /// Maximum fixed ticks run during one presentation callback.
    ///
    /// Caps recovery after a hitch to prevent a catch-up spiral. Older
    /// accumulated simulation time is discarded when the cap is reached.
    public let maximumUpdatesPerFrame: UInt32

    /// Creates a fixed-rate simulation policy.
    ///
    /// - Parameters:
    ///   - updatesPerSecond: Number of fixed simulation ticks per second.
    ///   - maximumUpdatesPerFrame: Maximum catch-up ticks permitted during one
    ///     presentation callback.
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

/// Runtime timing policy for variable and optional fixed simulation updates.
public struct LoopSettings: Hashable, Sendable {
    /// Largest variable-update delta accepted after a stalled presentation.
    ///
    /// A longer real-world interval is clamped to this value before it reaches
    /// ``Game/update(_:lanes:)``, preventing one stalled frame from producing
    /// an unexpectedly large simulation jump.
    public let maximumDeltaSeconds: Double

    /// Optional fixed-rate simulation policy.
    ///
    /// When present, the runtime invokes fixed updates from an accumulator and
    /// supplies ``RenderTime/interpolation`` for rendering between fixed states.
    /// Set to `nil` for variable-update-only games.
    public let fixedStep: FixedStep?

    /// Creates runtime timing policy.
    ///
    /// - Parameters:
    ///   - maximumDeltaSeconds: Largest variable-update delta accepted after a
    ///     stalled presentation callback.
    ///   - fixedStep: Optional fixed-rate simulation policy. Pass `nil` to use
    ///     variable updates only.
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

    /// Default policy: 60 Hz fixed simulation, up to eight catch-up ticks, and
    /// a 250 ms maximum variable delta.
    public static let `default` = Self()
}

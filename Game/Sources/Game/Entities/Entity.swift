import Pixl

protocol Entity {
    /// Invoked serially for each fixed simulation tick.
    mutating func fixedUpdate(_ time: FixedTime, context: GameContext)

    /// Invoked serially for each presentation update.
    mutating func update(_ time: UpdateTime, context: GameContext)

    /// Invoked on the leader lane because `Frame` recording is not yet
    /// lane-partitioned.
    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame,
        time: RenderTime,
        context: GameContext
    ) throws
}

extension Entity {
    /// Invoked serially for each fixed simulation tick.
    mutating func fixedUpdate(_ time: FixedTime, context: GameContext) { }

    /// Invoked serially for each presentation update.
    mutating func update(_ time: UpdateTime, context: GameContext) { }

    /// Invoked on the leader lane because `Frame` recording is not yet
    /// lane-partitioned.
    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame,
        time: RenderTime,
        context: GameContext
    ) throws { }
}

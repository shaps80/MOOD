import Pixl2D

/// Movement and discrete actions produced by one fixed controller step.
public struct PlatformerStep: Sendable {
    /// World-space displacement to apply before collision detection.
    public let displacement: Vec2
    /// Actions that began during this exact step.
    public let events: PlatformerEvents

    package init(
        displacement: Vec2,
        events: PlatformerEvents = []
    ) {
        self.displacement = displacement
        self.events = events
    }
}

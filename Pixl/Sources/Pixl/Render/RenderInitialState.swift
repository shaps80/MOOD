import PixlGraphics

/// Contents established before queued rendering begins.
public enum RenderInitialState: Hashable, Sendable {
    /// Replaces existing destination contents with one colour.
    case clear(Color)
    /// Keeps existing destination contents for queued rendering to build upon.
    case preserve
}

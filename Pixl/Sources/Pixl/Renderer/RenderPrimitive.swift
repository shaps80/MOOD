import Swift

/// A low-level render item after command expansion.
///
/// Render primitives are still platform-neutral. `RenderBatch` groups adjacent
/// primitives before `RenderPlanner` prepares upload-ready instances.
public enum RenderPrimitive: Equatable, Sendable {
    /// A texture sprite primitive.
    case sprite(PositionedSprite)

    /// A shape primitive produced from path rendering.
    case shape(ShapePrimitive)
}

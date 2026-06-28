import Swift

/// A platform-neutral batch ready for GPU upload.
///
/// Batches keep material identity and blend mode separate from per-instance
/// values so platform renderers can bind once and draw many instances.
public enum PreparedRenderBatch: Equatable, Sendable {
    /// Prepared sprite instances sharing the same texture and blend mode.
    case sprites(
        textureID: TextureID,
        blendMode: BlendMode,
        instances: [SpriteRenderInstance]
    )

    /// Prepared shape instances sharing the same blend mode.
    case shapes(
        blendMode: BlendMode,
        instances: [ShapeRenderInstance]
    )
}

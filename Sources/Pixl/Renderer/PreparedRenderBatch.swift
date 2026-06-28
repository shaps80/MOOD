import Swift

/// A platform-neutral batch ready for GPU upload.
///
/// Batches keep material identity and blend mode separate from per-instance
/// values so platform renderers can bind once and draw many instances.
public enum PreparedRenderBatch: Equatable, Sendable {
    case sprites(
        textureID: TextureID,
        blendMode: BlendMode,
        instances: [SpriteRenderInstance]
    )
    case shapes(
        blendMode: BlendMode,
        instances: [ShapeRenderInstance]
    )
}

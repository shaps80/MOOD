import Swift

/// A platform-neutral batch ready for GPU upload.
///
/// Batches keep material identity and blend mode separate from per-item values
/// so platform renderers can bind once and draw many items.
public enum PreparedRenderBatch: Equatable, Sendable {
    /// Prepared render items sharing the same texture, if any, and blend mode.
    case items(
        textureID: TextureID?,
        blendMode: BlendMode,
        items: [RenderItem]
    )
}

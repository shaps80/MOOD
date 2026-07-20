import Swift

/// Processing applied to a decoded colour texture's RGB channels.
public enum TextureAlpha: Hashable, Sendable {
    /// Multiplies decoded RGB by alpha before GPU upload.
    ///
    /// This is the default for sprites and produces correct interpolation at
    /// transparent edges when paired with premultiplied source-over blending.
    case premultiplied

    /// Uploads decoded RGBA channels without changing them.
    ///
    /// Normal sprite composition automatically uses straight-alpha blending
    /// for textures loaded this way.
    case passthrough
}

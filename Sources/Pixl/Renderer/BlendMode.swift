import Swift

/// How a new draw blends with pixels already in the frame.
///
/// Blend modes are platform-neutral. Pixl records the mode in render batches,
/// then each platform maps it to its graphics API.
///
/// ```swift
/// let glow = Sprite(
///     material: .sprite(.player, sourceRect: frame),
///     blendMode: .additive
/// )
/// ```
public enum BlendMode: Hashable, Sendable {
    /// Standard premultiplied-alpha blending.
    case normal

    /// Adds source color into the destination, useful for glow/light effects.
    case additive

    /// Multiplies source and destination color.
    case multiply

    /// Screens source over destination for a brightening effect.
    case screen

    /// Replaces the destination with the source.
    case replace
}

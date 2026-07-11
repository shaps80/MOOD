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
public enum BlendMode: Hashable, Sendable, CaseIterable {
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

    /// Combines multiply and screen depending on destination brightness.
    case overlay

    /// Keeps the darker source/destination channel.
    case darken

    /// Keeps the lighter source/destination channel.
    case lighten

    /// Brightens the destination based on the source.
    case colorDodge

    /// Darkens the destination based on the source.
    case colorBurn

    /// Applies a softer contrast blend than overlay.
    case softLight

    /// Combines multiply and screen depending on source brightness.
    case hardLight

    /// Shows the absolute channel difference.
    case difference

    /// Similar to difference with lower contrast.
    case exclusion

    /// Uses source hue with destination saturation and luminosity.
    case hue

    /// Uses source saturation with destination hue and luminosity.
    case saturation

    /// Uses source hue and saturation with destination luminosity.
    case color

    /// Uses source luminosity with destination hue and saturation.
    case luminosity
}

public extension BlendMode {
    /// Blend modes that can use fixed-function GPU blending.
    static let fixedFunctionModes: [BlendMode] = [
        .normal,
        .additive,
        .multiply,
        .screen,
        .replace
    ]

    /// Whether this mode samples the existing scene texture while drawing.
    var usesSceneSampling: Bool {
        !Self.fixedFunctionModes.contains(self)
    }

    /// Stable numeric value used by platform blend shaders.
    var shaderValue: Int {
        switch self {
        case .normal:
            return 0
        case .additive:
            return 1
        case .multiply:
            return 2
        case .screen:
            return 3
        case .replace:
            return 4
        case .overlay:
            return 5
        case .darken:
            return 6
        case .lighten:
            return 7
        case .colorDodge:
            return 8
        case .colorBurn:
            return 9
        case .softLight:
            return 10
        case .hardLight:
            return 11
        case .difference:
            return 12
        case .exclusion:
            return 13
        case .hue:
            return 14
        case .saturation:
            return 15
        case .color:
            return 16
        case .luminosity:
            return 17
        }
    }
}

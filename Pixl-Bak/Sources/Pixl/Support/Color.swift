import Swift

/// A normalized RGBA color used by Pixl render state.
///
/// Color channels are stored from `0...1`, matching the values render backends
/// typically pass to graphics APIs.
///
/// ```swift
/// let tint = Color(red: 1, green: 0.77, blue: 0, alpha: 1)
/// let faded = tint.opacity(0.5)
/// ```
public struct Color: Equatable, Sendable {
    /// The red channel, from `0...1`.
    ///
    /// ```swift
    /// let red = Color.red.red
    /// ```
    public private(set) var red: Double

    /// The green channel, from `0...1`.
    ///
    /// ```swift
    /// let green = Color.green.green
    /// ```
    public private(set) var green: Double

    /// The blue channel, from `0...1`.
    ///
    /// ```swift
    /// let blue = Color.blue.blue
    /// ```
    public private(set) var blue: Double

    /// The alpha channel, from `0...1`.
    ///
    /// ```swift
    /// let alpha = Color.white.alpha
    /// ```
    public private(set) var alpha: Double

    /// Creates a color from normalized RGBA channels.
    ///
    /// ```swift
    /// let color = Color(red: 0.75, green: 0.16, blue: 0.21, alpha: 1)
    /// ```
    public init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Returns a copy of the color with a different alpha channel.
    ///
    /// ```swift
    /// let translucent = Color.white.opacity(0.25)
    /// ```
    public func opacity(_ alpha: Double) -> Color {
        var copy = self
        copy.alpha = alpha
        return copy
    }
}

public extension Color {
    /// A fully transparent color.
    ///
    /// ```swift
    /// let hidden = Color.clear
    /// ```
    static let clear: Self = .init(
        red: 0,
        green: 0,
        blue: 0,
        alpha: 0
    )

    /// Solid white.
    ///
    /// ```swift
    /// let foreground = Color.white
    /// ```
    static let white: Self = .init(
        red: 1,
        green: 1,
        blue: 1,
        alpha: 1
    )

    /// Mid gray.
    ///
    /// ```swift
    /// let disabled = Color.gray
    /// ```
    static let gray: Self = .init(
        red: 0.5,
        green: 0.5,
        blue: 0.5,
        alpha: 1
    )

    /// Solid black.
    ///
    /// ```swift
    /// let shadow = Color.black
    /// ```
    static let black: Self = .init(
        red: 0,
        green: 0,
        blue: 0,
        alpha: 1
    )

    /// Pixl's default red accent.
    ///
    /// ```swift
    /// let damageFlash = Color.red
    /// ```
    static let red: Self = .init(
        red: 0.75,
        green: 0.16,
        blue: 0.21,
        alpha: 1
    )

    /// Pixl's default yellow accent.
    ///
    /// ```swift
    /// let pickupGlow = Color.yellow
    /// ```
    static let yellow: Self = .init(
        red: 1,
        green: 0.77,
        blue: 0,
        alpha: 1
    )

    /// Pixl's default green accent.
    ///
    /// ```swift
    /// let success = Color.green
    /// ```
    static let green: Self = .init(
        red: 0,
        green: 1,
        blue: 0.2,
        alpha: 1
    )

    /// Pixl's default blue accent.
    ///
    /// ```swift
    /// let debugOverlay = Color.blue
    /// ```
    static let blue: Self = .init(
        red: 0,
        green: 0,
        blue: 1,
        alpha: 1
    )

    /// A magenta fallback color for missing texture output.
    ///
    /// ```swift
    /// let fallback = Color.missingTexture
    /// ```
    static let missingTexture: Self = .init(
        red: 1,
        green: 0,
        blue: 1,
        alpha: 1
    )
}

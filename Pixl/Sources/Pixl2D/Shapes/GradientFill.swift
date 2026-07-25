import PixlGraphics

/// A retained colour ramp and its shape-local placement.
///
/// Construction bakes a premultiplied 256-sample row for the renderer's shared
/// gradient atlas. Store and reuse styled shapes as ordinary retained values.
public struct GradientFill: Hashable, Sendable {
    /// Shape-local gradient placement.
    public enum Placement: Hashable, Sendable {
        /// Projects colour stops along a directed line.
        case linear(from: Vec2, to: Vec2)
        /// Projects colour stops outwards from a centre point.
        case radial(center: Vec2, radius: Float)
        /// Projects colour stops around a centre point.
        case angular(center: Vec2, angle: Angle)
    }

    /// Colour ramp sampled by the fill.
    public let gradient: Gradient
    /// Shape-local placement used to sample the colour ramp.
    public let placement: Placement

    package let rgba8: [UInt8]
    package let fingerprint: UInt64

    /// Creates a directed linear gradient fill.
    /// - Parameters:
    ///   - gradient: Retained colour ramp.
    ///   - start: Finite local point receiving location `0`.
    ///   - end: Distinct finite local point receiving location `1`.
    public init(
        _ gradient: Gradient,
        from start: Vec2 = .init(-0.5, 0),
        to end: Vec2 = .init(0.5, 0)
    ) {
        precondition([start.x, start.y, end.x, end.y].allSatisfy(\.isFinite))
        precondition(start != end)
        self.gradient = gradient
        self.placement = .linear(from: start, to: end)
        let rgba8 = Self.rasterize(gradient)
        self.rgba8 = rgba8
        self.fingerprint = Self.fingerprint(rgba8)
    }

    /// Creates a radial gradient fill.
    /// - Parameters:
    ///   - gradient: Retained colour ramp.
    ///   - center: Finite local point receiving location `0`.
    ///   - radius: Positive local radius receiving location `1`.
    public init(_ gradient: Gradient, center: Vec2 = .zero, radius: Float) {
        precondition([center.x, center.y, radius].allSatisfy(\.isFinite))
        precondition(radius > 0)
        self.gradient = gradient
        self.placement = .radial(center: center, radius: radius)
        let rgba8 = Self.rasterize(gradient)
        self.rgba8 = rgba8
        self.fingerprint = Self.fingerprint(rgba8)
    }

    /// Creates an angular gradient fill.
    /// - Parameters:
    ///   - gradient: Retained colour ramp.
    ///   - center: Finite local point around which locations rotate.
    ///   - angle: Finite angle at which location `0` begins.
    public init(_ gradient: Gradient, center: Vec2 = .zero, angle: Angle) {
        precondition([center.x, center.y, angle.radians].allSatisfy(\.isFinite))
        self.gradient = gradient
        self.placement = .angular(center: center, angle: angle)
        let rgba8 = Self.rasterize(gradient)
        self.rgba8 = rgba8
        self.fingerprint = Self.fingerprint(rgba8)
    }

    private static func fingerprint(_ rgba8: [UInt8]) -> UInt64 {
        rgba8.reduce(0xcbf2_9ce4_8422_2325) {
            ($0 ^ UInt64($1)) &* 0x0000_0100_0000_01b3
        }
    }

    private static func rasterize(_ gradient: Gradient) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 256 * 4)
        for index in 0..<256 {
            let location = Float(index) / 255
            let color = sample(gradient, at: location)
            let alpha = min(max(color.opacity, 0), 1)
            bytes[index * 4] = byte(min(max(color.red, 0), 1) * alpha)
            bytes[index * 4 + 1] = byte(min(max(color.green, 0), 1) * alpha)
            bytes[index * 4 + 2] = byte(min(max(color.blue, 0), 1) * alpha)
            bytes[index * 4 + 3] = byte(alpha)
        }
        return bytes
    }

    private static func sample(_ gradient: Gradient, at location: Float) -> Color {
        guard gradient.stops.count > 1 else { return gradient.stops[0].color }
        if location <= gradient.stops[0].location { return gradient.stops[0].color }
        for index in 1..<gradient.stops.count {
            let upper = gradient.stops[index]
            guard location <= upper.location else { continue }
            let lower = gradient.stops[index - 1]
            guard upper.location > lower.location else { return upper.color }
            let amount = Float((location - lower.location) / (upper.location - lower.location))
            return lower.color + (upper.color - lower.color) * amount
        }
        return gradient.stops[gradient.stops.count - 1].color
    }

    private static func byte(_ value: Float) -> UInt8 {
        UInt8((value * 255).rounded())
    }
}

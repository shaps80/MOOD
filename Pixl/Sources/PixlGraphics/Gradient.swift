import Swift

/// A retained colour ramp described by ordered colour stops.
public struct Gradient: Hashable, Sendable {
    /// One colour at a normalized location in the gradient.
    public struct Stop: Hashable, Sendable {
        /// Colour at ``location``.
        public var color: Color
        /// Normalized location in `0...1`.
        public var location: Float

        /// Creates a colour stop.
        /// - Parameters:
        ///   - color: Colour at the stop.
        ///   - location: Finite normalized location in `0...1`.
        public init(color: Color, location: Float) {
            precondition(location.isFinite && (0...1).contains(location))
            self.color = color
            self.location = location
        }
    }

    /// Stops sorted by ascending location. Equal locations retain input order.
    public var stops: [Stop]

    /// Creates a gradient by evenly distributing one or more colours.
    /// - Parameter colors: Nonempty colour sequence. One colour creates a constant ramp.
    public init(colors: [Color]) {
        precondition(!colors.isEmpty, "A gradient requires at least one colour")
        if colors.count == 1 {
            stops = [.init(color: colors[0], location: 0)]
        } else {
            let denominator = Float(colors.count - 1)
            stops = colors.enumerated().map {
                .init(color: $0.element, location: Float($0.offset) / denominator)
            }
        }
    }

    /// Creates a gradient from one or more explicit stops.
    /// - Parameter stops: Stops with finite normalized locations. Equal locations create hard transitions.
    public init(stops: [Stop]) {
        precondition(!stops.isEmpty, "A gradient requires at least one stop")
        self.stops = stops.enumerated().sorted {
            $0.element.location == $1.element.location
                ? $0.offset < $1.offset
                : $0.element.location < $1.element.location
        }.map(\.element)
    }
}

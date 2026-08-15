import Swift

public struct Particle {
    public internal(set) var position: SIMD2<Float>
}

public struct System {
    public init() { }

    public func sample(at instant: ContinuousClock.Instant) -> [Particle] {
        [.init(position: .zero)]
    }
}

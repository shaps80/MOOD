import Swift

public typealias Vec2 = SIMD2<Float>

public struct Particle {
    public internal(set) var position: Vec2

    var previousPosition: Vec2
    let velocity: Vec2

    init(
        position: Vec2,
        velocity: Vec2
    ) {
        previousPosition = position
        self.position = position
        self.velocity = velocity
    }

    public func interpolated(by fraction: Float) -> Vec2 {
        previousPosition + (position - previousPosition) * fraction
    }

    mutating func advance(by delta: Float) {
        previousPosition = position
        position += velocity * delta
    }
}

public struct Sample {
    public let particles: [Particle]
    public let interpolation: Float
}

public final class System {
    private var loop = Loop(settings: .default)
    private var particles: [Particle]

    public init() {
        particles = [
            .init(position: .zero, velocity: [20, 0]),
            .init(position: [5, 0], velocity: [0, 20]),
            .init(position: [-5, 0], velocity: [-20, 0]),
        ]
    }

    public func sample(at instant: ContinuousClock.Instant) -> Sample {
        let schedule = loop.advance(to: instant)
        let delta = Float(schedule.fixedDeltaSeconds)
        let interpolation = Float(schedule.renderTime.interpolation)

        for _ in 0..<schedule.fixedUpdateCount {
            for index in particles.indices {
                particles[index].advance(by: delta)
            }
        }

        return .init(
            particles: particles,
            interpolation: interpolation
        )
    }
}

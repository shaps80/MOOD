import Pixl

struct InvadersCamera: GameSystem {
    private var shake = CameraShake()
    private var shakeCooldown: Double = 0

    mutating func update(context: inout Game.SystemContext) {
        shakeCooldown = max(shakeCooldown - context.delta, 0)

        if shakeCooldown == 0, didHitInvader(context: context) {
            shake.trigger()
            shakeCooldown = 1
        }

        context.camera.transform = shake.update(delta: context.delta)
    }

    private func didHitInvader(context: Game.SystemContext) -> Bool {
        let bullets = Set(context.ids(kind: Bullet.self))

        guard !bullets.isEmpty else {
            return false
        }

        for invader in context.ids(kind: Invader.self) {
            for contact in context.contacts(for: invader) {
                guard contact.phase == .began,
                      let target = contact.target.id,
                      bullets.contains(target)
                else {
                    continue
                }

                return true
            }
        }

        return false
    }
}

private struct CameraShake {
    private let duration: Double = 0.2
    private let baseAmplitude: Double = 5
    private let baseRotation: Angle = .degrees(0.75)
    private let baseFrequency: Double = 35

    private var elapsed: Double = .infinity
    private var triggerCount: Int = 0
    private var phase: Double = 0
    private var amplitude: Double = 3
    private var rotation: Angle = .degrees(0.75)
    private var frequency: Double = 42

    mutating func trigger() {
        triggerCount += 1
        elapsed = 0

        let seed = Double(triggerCount)
        phase = seed * 1.61803398875 * .pi * 2
        amplitude = baseAmplitude * scale(seed: seed, salt: 12.9898, range: 0.9...1.1)
        rotation = baseRotation * scale(seed: seed, salt: 78.233, range: 0.85...1.15)
        frequency = baseFrequency * scale(seed: seed, salt: 37.719, range: 0.92...1.08)
    }

    mutating func update(delta: Double) -> Transform {
        guard elapsed < duration else {
            return .identity
        }

        elapsed = min(elapsed + max(delta, 0), duration)

        let progress = elapsed / duration
        let fade = 1 - progress

        guard fade > 0 else {
            return .identity
        }

        let wave = (elapsed * frequency * .pi * 2) + phase

        return Transform(
            position: Vec2(
                x: sin(.radians(wave)) * amplitude * fade,
                y: cos(.radians((wave * 1.37) + phase)) * amplitude * 0.65 * fade
            ),
            rotation: rotation * (sin(.radians((wave * 0.73) + phase)) * fade)
        )
    }

    private func scale(
        seed: Double,
        salt: Double,
        range: ClosedRange<Double>
    ) -> Double {
        let unit = deterministicUnit(seed: seed, salt: salt)
        return range.lowerBound + ((range.upperBound - range.lowerBound) * unit)
    }

    private func deterministicUnit(seed: Double, salt: Double) -> Double {
        let value = sin(.radians(seed * salt)) * 43758.5453123
        return value - value.rounded(.down)
    }
}

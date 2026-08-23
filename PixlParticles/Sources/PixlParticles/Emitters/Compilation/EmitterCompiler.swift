import Swift

struct EmitterCompiler {
    private static let maximumCapacity = 1 << 31

    private let updatesPerSecond: UInt32

    init(updatesPerSecond: UInt32 = 60) {
        precondition(updatesPerSecond > 0 && updatesPerSecond < 1 << 31)
        self.updatesPerSecond = updatesPerSecond
    }

    func compile(_ emitter: Emitter) -> CompiledEmitter {
        let properties = PropertyCompiler()
        let spawnRate = properties.compile(
            emitter.spawnRate,
            using: .constant(default: 0) { value in
                precondition(value.isFinite && value >= 0)
            }
        )
        let lifetime = properties.compile(
            emitter.lifetime,
            using: .constant(default: 1) { value in
                precondition(value.isFinite && value > 0)
            }
        )
        let velocity = properties.compile(
            emitter.velocity,
            using: .velocity
        )
        let color = properties.compile(
            emitter.color,
            using: .constant(default: .white)
        )
        let size = properties.compile(
            emitter.size,
            using: .constant(default: [1, 1]) { size in
                precondition(
                    size.x.isFinite && size.y.isFinite
                        && size.x >= 0 && size.y >= 0
                )
            }
        )
        let rotation = properties.compile(
            emitter.rotation,
            using: .constant(default: 0) { rotation in
                precondition(rotation.isFinite)
            }
        )
        precondition(
            emitter.position.isEmpty,
            "Position property lowering has not been integrated yet"
        )
        var effects = PropertyCompiler.Effects()
        effects.formUnion(spawnRate.effects)
        effects.formUnion(lifetime.effects)
        effects.formUnion(velocity.effects)
        effects.formUnion(color.effects)
        effects.formUnion(size.effects)
        effects.formUnion(rotation.effects)

        let lifetimeTicks = max(
            1,
            (Double(lifetime.value) * Double(updatesPerSecond)).rounded(.up)
        )
        precondition(lifetimeTicks <= Double(UInt32.max))
        let compiledSpawnRate = compileSpawnRate(spawnRate.value)
        let wholeCapacity = UInt64(compiledSpawnRate.whole)
            * UInt64(lifetimeTicks)
        let fractionalCapacity = divideRoundingUp(
            compiledSpawnRate.remainder,
            multipliedBy: UInt64(lifetimeTicks),
            dividedBy: compiledSpawnRate.denominator
        )
        let capacity = wholeCapacity + fractionalCapacity
        precondition(
            capacity < UInt64(Self.maximumCapacity)
        )

        return CompiledEmitter(
            storage: .init(
                capacity: Int(capacity),
                requirements: effects.storage
            ),
            constants: .init(
                spawnRegion: emitter.spawnRegion,
                spawnRate: compiledSpawnRate,
                lifetimeTicks: UInt32(lifetimeTicks),
                velocity: velocity.value,
                color: color.value,
                size: size.value,
                rotation: rotation.value
            ),
            passes: [.spawn] + effects.passes,
            renderers: emitter.renderers
        )
    }

    private func compileSpawnRate(_ rate: Float) -> CompiledEmitter.SpawnRate {
        let rateScale: UInt64 = 1 << 32
        let numerator = UInt64((Double(rate) * Double(rateScale)).rounded())
        let denominator = UInt64(updatesPerSecond) * rateScale
        let whole = numerator / denominator
        precondition(whole <= UInt64(UInt32.max))
        return .init(
            whole: UInt32(whole),
            remainder: numerator % denominator,
            denominator: denominator
        )
    }

    private func divideRoundingUp(
        _ value: UInt64,
        multipliedBy multiplier: UInt64,
        dividedBy divisor: UInt64
    ) -> UInt64 {
        let product = value.multipliedFullWidth(by: multiplier)
        let division = divisor.dividingFullWidth(product)
        return division.quotient + (division.remainder == 0 ? 0 : 1)
    }
}

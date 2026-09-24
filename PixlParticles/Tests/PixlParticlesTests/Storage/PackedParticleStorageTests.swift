import Testing
import PixlRenderer
@testable import PixlParticles

struct PackedParticleStorageTests {
    @Test func byteBudgetAndPaletteCapacity() {
        let moving = EmitterStorageLayout(capacity: 100, requirements: [.velocity])
        let stationary = EmitterStorageLayout(capacity: 100, requirements: [])
        let metadata = Metadata(capacity: 100, count: 0)
        #expect(moving.byteCount + metadata.byteCount == 100 * 32)
        #expect(stationary.byteCount + metadata.byteCount == 100 * 24)
        let colors = (0..<65_536).map { Color(red: Float($0), green: 0, blue: 0, alpha: 0.5) }
        let palette = ParticleColorPalette(colors)
        #expect(palette.index(of: colors[65_535]) == UInt16.max)
        #expect(palette[UInt16.max] == colors[65_535])
        palette.storage.withUnsafeBytes { bytes in
            let values = bytes.bindMemory(to: SIMD4<Float>.self)
            #expect(values[65_535] == [32_767.5, 0, 0, 0.5])
        }
    }

    @Test func integrationCompactionAndInterpolationReset() {
        let color = Color(red: 2, green: 1, blue: 0.5, alpha: 0.5)
        let storage = ParticleStorage(capacity: 8, velocityPacking: .init(maximumMagnitude: 511), palette: .init([color]))
        storage.appendMoving(Particle(id: 0, position: [1, 2, 3], velocity: [2, -4, 6], color: color), slot: 0)
        storage.appendMoving(Particle(id: 1, position: [4, 5, 6], velocity: [-2, 4, -6], color: color), slot: 1)
        storage.advance(by: 0.25)
        let before = storage.particles { UInt64($0) }
        #expect(before[0].position == [1.5, 1, 4.5])
        #expect(before[0].previousPosition == [1, 2, 3])
        #expect(before[0].color == color)
        #expect(storage.removeMoving(at: 0) == 1)
        let after = storage.particles { UInt64($0) }
        #expect(after[0].position == before[1].position)
        #expect(after[0].previousPosition == before[1].previousPosition)
        #expect(after[0].velocity == before[1].velocity)
        storage.resetInterpolation()
        let reset = storage.particles { UInt64($0) }
        #expect(reset[0].previousPosition == reset[0].position)
    }
}

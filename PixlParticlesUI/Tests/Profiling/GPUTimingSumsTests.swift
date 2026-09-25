import PixlRenderer
import Testing
@testable import ParticleProfiling

@MainActor
struct GPUTimingSumsTests {
    @Test func missingCountersAreNotZeroAndEvictionRemovesAvailability() {
        var sums = GPUTimingSums()
        sums.add(.init(total: 0.01, vertex: 0.004))
        sums.add(.init(total: 0.02))
        #expect(sums.average.total == 0.015)
        #expect(sums.average.vertex == 0.004)
        #expect(sums.average.fragment == nil)
        sums.add(.init(total: 0.01, vertex: 0.004), sign: -1)
        #expect(sums.average.vertex == nil)
        #expect(abs((sums.average.total ?? 0) - 0.02) < 1e-12)
        sums.add(.init(preparation: 0))
        #expect(sums.average.preparation == 0)
    }
}

import Testing
@testable import PixlParticles

struct BirthCohortsTests {
    @Test func contiguousBirthsUseSharedExpiry() {
        let cohorts = BirthCohorts(capacity: 10_000, lifetimeTicks: 2)
        let bytes = cohorts.byteCount
        for slot: UInt32 in 0..<10_000 { cohorts.schedule(slot, deathTick: 2) }
        #expect(cohorts.byteCount == bytes)
        #expect(cohorts.popExpired(at: 1) == nil)
        for slot: UInt32 in 0..<10_000 { #expect(cohorts.popExpired(at: 2) == slot) }
        #expect(cohorts.popExpired(at: 2) == nil)
    }

    @Test func removalSplitsRangesAndReuseKeepsNewExpiry() {
        let cohorts = BirthCohorts(capacity: 8, lifetimeTicks: 1)
        for slot: UInt32 in 0..<8 { cohorts.schedule(slot, deathTick: 4) }
        cohorts.remove(0)
        cohorts.remove(3)
        cohorts.remove(7)
        cohorts.schedule(3, deathTick: 5)
        for slot: UInt32 in [1, 2, 4, 5, 6] { #expect(cohorts.popExpired(at: 4) == slot) }
        #expect(cohorts.popExpired(at: 4) == nil)
        #expect(cohorts.popExpired(at: 5) == 3)
        #expect(cohorts.popExpired(at: 5) == nil)
    }

    @Test func queueGrowthWraparoundAndTickWrap() {
        let cohorts = BirthCohorts(capacity: 20, lifetimeTicks: 1)
        cohorts.schedule(0, deathTick: .max)
        cohorts.schedule(2, deathTick: .max)
        #expect(cohorts.popExpired(at: .max) == 0)
        for slot: UInt32 in [4, 6, 8, 10] { cohorts.schedule(slot, deathTick: 0) }
        #expect(cohorts.popExpired(at: .max) == 2)
        #expect(cohorts.popExpired(at: .max) == nil)
        for slot: UInt32 in [4, 6, 8, 10] { #expect(cohorts.popExpired(at: 0) == slot) }
        cohorts.reset()
        cohorts.schedule(1, deathTick: 1)
        #expect(cohorts.popExpired(at: 1) == 1)
    }
}

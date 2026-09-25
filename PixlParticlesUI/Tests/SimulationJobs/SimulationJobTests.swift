import Foundation
import PixlProfiler
import Testing
@testable import PixlParticles
@testable import SimulationJobs

@Suite(.serialized)
struct SimulationJobTests {
    @Test func suspendedPoolDoesNotBurnCPU() {
        let pool = SpinningJobPool(workerCount: 4)
        withUnsafePointer(to: 0) { pointer in
            pool.execute(SimulationJob(count: 100, context: pointer) { _, _ in })
        }
        pool.setSuspended(true)
        Thread.sleep(forTimeInterval: 0.02)
        var before = rusage(), after = rusage()
        getrusage(RUSAGE_SELF, &before)
        Thread.sleep(forTimeInterval: 0.3)
        getrusage(RUSAGE_SELF, &after)
        let cpu = Double(after.ru_utime.tv_sec + after.ru_stime.tv_sec
            - before.ru_utime.tv_sec - before.ru_stime.tv_sec)
            + Double(after.ru_utime.tv_usec + after.ru_stime.tv_usec
                - before.ru_utime.tv_usec - before.ru_stime.tv_usec) / 1e6
        #expect(cpu < 0.15, "Idle workers consumed \(cpu) CPU seconds in 0.3s")
        withExtendedLifetime(pool) {}
    }

    @Test func suspendedPoolResumesForJobsAndShutsDown() {
        for workers in [1, 2, 4] {
            let pool = SpinningJobPool(workerCount: workers)
            let storage = UnsafeMutablePointer<Int>.allocate(capacity: 103)
            storage.initialize(repeating: 0, count: 103)
            defer { storage.deinitialize(count: 103); storage.deallocate() }
            for _ in 0..<200 {
                pool.setSuspended(true)
                pool.execute(SimulationJob(count: 103, context: storage) { pointer, range in
                    let values = UnsafeMutableRawPointer(mutating: pointer).assumingMemoryBound(to: Int.self)
                    for i in range { values[i] += 1 }
                })
            }
            #expect((0..<103).allSatisfy { storage[$0] == 200 })
            pool.setSuspended(true)
        }
    }

    @Test func tracedJobsRemainCoherentAcrossPauseAndResume() {
        let session = ProfileSession(scopes: [JobProfileDefinitions.dispatch,
                                             JobProfileDefinitions.batch, JobProfileDefinitions.spin])
        let owner = session.prepare(ProfileTrack(0, "Owner"))
        let workers = (1..<4).map { session.prepare(ProfileTrack(1, "Worker"), instance: $0) }
        let pool = SpinningJobPool(workerCount: 4, recorder: owner, workerRecorders: workers)
        let storage = UnsafeMutablePointer<Int>.allocate(capacity: 10_003)
        storage.initialize(repeating: 0, count: 10_003)
        defer { storage.deinitialize(count: 10_003); storage.deallocate() }
        for round in 0..<3 {
            session.resume()
            for index in 1...50 {
                pool.frameID = UInt64(index)
                pool.execute(SimulationJob(count: 10_003, context: storage) { pointer, range in
                    let values = UnsafeMutableRawPointer(mutating: pointer).assumingMemoryBound(to: Int.self)
                    for i in range { values[i] += 1 }
                })
            }
            pool.setSuspended(true)
            session.freeze()
            let snapshot = session.snapshot()
            let batches = snapshot.segments.filter { $0.scope == JobProfileDefinitions.batch.id }
            #expect(batches.count == 50 * 16)
            #expect(batches.allSatisfy { (1...50).contains($0.correlation) && $0.detail < 16 })
            #expect(snapshot.dropped == 0)
            #expect((0..<10_003).allSatisfy { storage[$0] == (round + 1) * 50 })
        }
    }

    @Test func exactCoverageAndRepeatedDispatch() {
        for workers in [1, 2, 4] {
            let pool = SpinningJobPool(workerCount: workers, batchesPerWorker: 4)
            let storage = UnsafeMutablePointer<Int>.allocate(capacity: 1003)
            storage.initialize(repeating: 0, count: 1003)
            defer { storage.deinitialize(count: 1003); storage.deallocate() }
            for count in [0, 1, 3, 17, 1003, 2, 999] {
                for generation in 1...50 {
                    storage.update(repeating: 0, count: 1003)
                    pool.execute(SimulationJob(count: count, context: storage) { pointer, range in
                        let values = UnsafeMutableRawPointer(mutating: pointer).assumingMemoryBound(to: Int.self)
                        for i in range { values[i] += 1 }
                    })
                    #expect((0..<1003).allSatisfy { storage[$0] == ($0 < count ? 1 : 0) }, "generation \(generation)")
                }
            }
        }
    }

    @Test func simulationMatchesSerial() {
        let pool = SpinningJobPool(workerCount: 4)
        for moving in [false, true] {
            for rate: Float in [0, 1, 301, 60_017] {
                var emitter = Emitter(spawnRegion: .sphere(radius: 100, domain: .surface))
                emitter[\.spawnRate].append(.set(rate))
                emitter[\.lifetime].append(.set(0.117))
                if moving {
                    emitter[\.velocity].append(.set(.random(from: [-20, -20, -20], to: [20, 20, 20], variation: .perValue)))
                }
                let serial = System(seed: 123, emitter: emitter, duration: .zero)
                let parallel = System(seed: 123, emitter: emitter, duration: .zero)
                parallel.executor = pool
                for tick in 0..<50 {
                    serial.update(by: 1.0 / 60)
                    parallel.update(by: 1.0 / 60)
                    equal(serial, parallel)
                    if tick == 20, let id = serial.particleSnapshot.first?.id {
                        #expect(serial.emitter.remove(id))
                        #expect(parallel.emitter.remove(id))
                    }
                }
                for time in [0.2, 1.1, 0, 0.5] {
                    serial.seek(to: .seconds(time))
                    parallel.seek(to: .seconds(time))
                    equal(serial, parallel)
                }
            }
        }
    }

    @Test func changedSpawnRateWithSameArena() {
        let pool = SpinningJobPool(workerCount: 4)
        var emitter = Emitter(spawnRegion: .sphere(radius: 10))
        emitter[\.spawnRate].append(.set(60))
        emitter[\.lifetime].append(.set(2))
        let serial = EmitterInstance(emitter: emitter)
        let parallel = EmitterInstance(emitter: emitter)
        serial.advance(by: 1.0 / 60)
        parallel.advance(by: 1.0 / 60, executor: pool)
        emitter[\.spawnRate][0] = .set(7200)
        emitter[\.lifetime][0] = .set(1.0 / 120)
        let compiled = EmitterCompiler().compile(emitter)
        #expect(serial.apply(compiled) == .reusedArena)
        #expect(parallel.apply(compiled) == .reusedArena)
        for _ in 0..<10 {
            serial.advance(by: 1.0 / 60)
            parallel.advance(by: 1.0 / 60, executor: pool)
            #expect(serial.particles().map(\.position) == parallel.particles().map(\.position))
        }
    }

    private func equal(_ a: System, _ b: System) {
        let a = a.particleSnapshot, b = b.particleSnapshot
        #expect(a.count == b.count)
        #expect(zip(a, b).allSatisfy {
            $0.id == $1.id && bits($0.position, $1.position)
                && bits($0.previousPosition, $1.previousPosition)
                && bits($0.velocity, $1.velocity) && $0.color == $1.color
        })
    }
    private func bits(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Bool {
        a.x.bitPattern == b.x.bitPattern && a.y.bitPattern == b.y.bitPattern
            && a.z.bitPattern == b.z.bitPattern
    }

}

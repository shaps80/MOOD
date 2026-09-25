import Dispatch
import Foundation
import PixlParticles
import PixlRenderer
import Testing
@testable import ParticleMailbox

struct MailboxTests {
    private func system() -> System {
        System(seed: 0, emitter: Emitter(spawnRegion: .point(.zero)), duration: .seconds(10))
    }

    private func frame(_ budget: Double) -> Mailbox.Frame {
        Mailbox.Frame(
            isPaused: false, capturesDiagnostics: false, frameBudget: budget,
            renderer: .init(), renderValues: .init(), pointLOD: .init(),
            editor: .init(), cullingBounds: .init(), cullingViewProjection: .identity,
            camera: .init(viewProjection: .identity, position: .zero,
                          right: [1, 0, 0], up: [0, 1, 0],
                          viewport: .init(width: 100, height: 100))
        )
    }

    @Test func coalescingPreservesControlsAndDoesNotReplayThem() {
        let original = system()
        let replacement = system()
        let mailbox = Mailbox(system: original)
        #expect(mailbox.next().system === original)
        mailbox.replaceSystem(replacement)
        mailbox.seek(to: .seconds(1))
        mailbox.seek(to: .seconds(2))
        mailbox.setDuration(.seconds(20))
        for value in 1...100 { mailbox.submit(frame(Double(value))) }
        let work = mailbox.next()
        #expect(work.system === replacement)
        #expect(work.seekTime == .seconds(2))
        #expect(work.duration == .seconds(20))
        #expect(work.frame?.frameBudget == 100)
        mailbox.submit(frame(101))
        let next = mailbox.next()
        #expect(next.frame?.frameBudget == 101)
        #expect(next.system == nil)
        #expect(next.seekTime == nil)
        #expect(next.duration == nil)
        mailbox.seek(to: .seconds(2))
        let repeatedSeek = mailbox.next()
        #expect(repeatedSeek.seekTime == .seconds(2))
        #expect(repeatedSeek.frame == nil)
    }

    @Test func completedTimesCoalesceAndFailurePersists() {
        let mailbox = Mailbox(system: system())
        mailbox.complete(at: .seconds(1))
        mailbox.complete(at: .seconds(2))
        #expect(mailbox.result().time == .seconds(2))
        #expect(mailbox.result().time == nil)
        mailbox.fail("test failure")
        let failed = mailbox.result()
        #expect(failed.time == nil)
        #expect(failed.failure == "test failure")
        #expect(mailbox.result().failure == "test failure")
    }

    @Test func parkedWorkerReceivesControlAndShutdown() {
        let mailbox = Mailbox(system: system())
        _ = mailbox.next()
        let ready = DispatchGroup()
        let finished = DispatchGroup()
        ready.enter()
        finished.enter()
        DispatchQueue.global().async {
            ready.leave()
            let work = mailbox.next()
            #expect(work.seekTime == .seconds(3))
            mailbox.complete(at: .seconds(3))
            let stop = mailbox.next()
            #expect(stop.shouldStop)
            finished.leave()
        }
        #expect(ready.wait(timeout: .now() + 5) == .success)
        mailbox.seek(to: .seconds(3))
        // Only the test waits on results; production UI never spins here.
        var received = false
        let deadline = DispatchTime.now().uptimeNanoseconds + 5_000_000_000
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if mailbox.result().time == .seconds(3) { received = true; break }
        }
        #expect(received)
        mailbox.stop()
        #expect(finished.wait(timeout: .now() + 5) == .success)
    }

    @Test func idleWorkerDoesNotBurnCPU() {
        let mailbox = Mailbox(system: system())
        _ = mailbox.next()
        let finished = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            var before = timespec(), after = timespec()
            clock_gettime(CLOCK_THREAD_CPUTIME_ID, &before)
            #expect(mailbox.next().shouldStop)
            clock_gettime(CLOCK_THREAD_CPUTIME_ID, &after)
            let cpu = Double(after.tv_sec - before.tv_sec)
                + Double(after.tv_nsec - before.tv_nsec) / 1e9
            #expect(cpu < 0.05, "Empty mailbox consumed \(cpu) CPU seconds")
            finished.signal()
        }
        Thread.sleep(forTimeInterval: 0.3)
        mailbox.stop()
        #expect(finished.wait(timeout: .now() + 5) == .success)
    }

    @Test func repeatedParkAndPublishDoesNotLoseWakeups() {
        let mailbox = Mailbox(system: system())
        _ = mailbox.next()
        let received = DispatchSemaphore(value: 0)
        let finished = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            for value in 1...1000 {
                let work = mailbox.next()
                #expect(work.seekTime == .seconds(value))
                received.signal()
            }
            #expect(mailbox.next().shouldStop)
            finished.signal()
        }
        for value in 1...1000 {
            mailbox.seek(to: .seconds(value))
            guard received.wait(timeout: .now() + 5) == .success else {
                Issue.record("Lost mailbox wakeup")
                mailbox.stop()
                return
            }
        }
        mailbox.stop()
        #expect(finished.wait(timeout: .now() + 5) == .success)
    }

    @Test func stopTakesPriorityOverPendingWork() {
        let mailbox = Mailbox(system: system())
        mailbox.seek(to: .seconds(1))
        mailbox.stop()
        #expect(mailbox.next().shouldStop)
    }
}

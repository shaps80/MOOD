#if canImport(SwiftUI)
import Foundation
import Synchronization
import PixlProfiler

/// This queue is the sole session/control consumer after setup. Never accessed
/// by application recording threads. Frozen sessions have no repeating timer.
final class ProfileProcessor: @unchecked Sendable {
    let session: ProfileSession
    let queue = DispatchQueue(label: "Pixl Profiler Consumer", qos: .utility)
    var deliver: (@Sendable (ProfileSnapshot) -> Void)? // Set once before resume.
    private var timer: DispatchSourceTimer?
    private let frozen = Atomic<Bool>(true)
    private let completions: DispatchSourceUserDataAdd
    init(session: ProfileSession) {
        self.session = session
        completions = DispatchSource.makeUserDataAddSource(queue: queue)
        completions.setEventHandler { [weak self] in
            guard let self, timer == nil else { return }
            deliver?(session.snapshot())
        }
        completions.resume()
    }
    deinit { timer?.cancel(); completions.cancel() }
    func externalCompletion() {
        if frozen.load(ordering: .acquiring) { completions.add(data: 1) }
    }
    func resume() {
        queue.async { [self] in
            guard timer == nil else { return }
            frozen.store(false, ordering: .releasing)
            session.resume()
            deliver?(session.snapshot())
            let source = DispatchSource.makeTimerSource(queue: queue)
            source.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(50))
            source.setEventHandler { [weak self] in
                guard let self else { return }
                deliver?(session.snapshot())
            }
            timer = source; source.resume()
        }
    }
    func freeze() {
        queue.async { [self] in
            timer?.cancel(); timer = nil
            // Set before freezing/draining so a racing completion either appears
            // in this drain or schedules another one. No late result is stranded.
            frozen.store(true, ordering: .releasing)
            session.freeze()
            deliver?(session.snapshot())
        }
    }
}
#endif

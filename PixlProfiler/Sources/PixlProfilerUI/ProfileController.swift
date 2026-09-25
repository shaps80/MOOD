#if canImport(SwiftUI)
import SwiftUI
import PixlProfiler

/// Owns processing away from application workers. Prepare recorders before init.
@MainActor @Observable
public final class ProfileController {
    public private(set) var snapshot = ProfileSnapshot()
    @ObservationIgnored private let processor: ProfileProcessor
    public init(session: ProfileSession) {
        processor = ProfileProcessor(session: session)
        processor.deliver = { [weak self] value in
            DispatchQueue.main.async { [weak self] in self?.snapshot = value }
        }
    }
    /// Prepare once, invoke after asynchronous external events are recorded.
    /// Frozen captures refresh when results arrive without a polling timer.
    public func externalCompletionHandler() -> @Sendable () -> Void {
        let processor = processor
        return { processor.externalCompletion() }
    }
    deinit { processor.freeze() }
    public func resume() { processor.resume() }
    public func freeze() { processor.freeze() }
}
#endif

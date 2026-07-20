import PixlPlatform
import Swift

/// Coalesces noisy file changes without knowing how any asset is reloaded.
struct ReloadMonitor: Sendable {
    let delay: Duration

    init(delay: Duration = .milliseconds(75)) {
        self.delay = delay
    }

    func run(
        _ changes: AsyncStream<AssetChange>,
        yield: @escaping @Sendable (AssetChange) -> Void
    ) async {
        var pending: [AssetPath: Task<Void, Never>] = [:]
        defer {
            for task in pending.values { task.cancel() }
        }

        for await change in changes {
            guard !Task.isCancelled else { return }
            pending[change.path]?.cancel()
            pending[change.path] = Task {
                do {
                    try await Task.sleep(for: delay)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                yield(change)
            }
        }
    }
}

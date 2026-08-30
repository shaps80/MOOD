final class CollisionReportBuffer2D {
    private(set) var reports: UnsafeMutablePointer<Collision2D>
    private(set) var count = 0
    private var capacity: Int

    init(capacity: Int = 16) {
        self.capacity = max(capacity, 16)
        reports = .allocate(capacity: self.capacity)
    }

    deinit {
        reports.deinitialize(count: count)
        reports.deallocate()
    }

    func reset() {
        reports.deinitialize(count: count)
        count = 0
    }

    func append(_ report: Collision2D) {
        if count == capacity { grow() }
        reports.advanced(by: count).initialize(to: report)
        count += 1
    }

    private func grow() {
        let newCapacity = capacity + max(capacity / 2, 1)
        let newReports = UnsafeMutablePointer<Collision2D>.allocate(
            capacity: newCapacity
        )
        newReports.moveInitialize(from: reports, count: count)
        reports.deallocate()
        reports = newReports
        capacity = newCapacity
    }
}

import Swift

/// Fixed-capacity retained storage for one RenderQueue's sprite snapshots.
package final class SpriteSubmissions {
    package let capacity: Int
    package private(set) var count = 0

    private let records: UnsafeMutablePointer<SpriteSubmission>
    private let orders: UnsafeMutablePointer<RenderOrder>
    private var layersAreOrdered = true
    private var lastLayer: Int?

    package init(capacity: Int) {
        precondition(
            capacity > 0,
            "Sprite submission capacity must be greater than zero"
        )
        self.capacity = capacity
        records = .allocate(capacity: capacity)
        orders = .allocate(capacity: capacity)
    }

    deinit {
        reset()
        records.deallocate()
        orders.deallocate()
    }

    /// Appends one immutable snapshot without allocating or growing storage.
    @discardableResult
    package func append(
        _ submission: SpriteSubmission,
        layer: Int
    ) -> Bool {
        guard count < capacity else { return false }

        if let lastLayer, layer < lastLayer {
            layersAreOrdered = false
        }
        lastLayer = layer

        records.advanced(by: count).initialize(to: submission)
        orders.advanced(by: count).initialize(
            to: RenderOrder(
                layer: layer,
                ordinal: count
            )
        )
        count += 1
        return true
    }

    /// Provides ordered snapshots for encoding, then consumes every record.
    package func consume<Result, Failure: Error>(
        _ body: (
            UnsafeBufferPointer<RenderOrder>,
            UnsafeBufferPointer<SpriteSubmission>
        ) throws(Failure) -> Result
    ) throws(Failure) -> Result {
        if !layersAreOrdered {
            var order = UnsafeMutableBufferPointer(
                start: orders,
                count: count
            )
            order.sort()
        }

        defer { reset() }
        return try body(
            UnsafeBufferPointer(start: orders, count: count),
            UnsafeBufferPointer(start: records, count: count)
        )
    }

    private func reset() {
        records.deinitialize(count: count)
        orders.deinitialize(count: count)
        count = 0
        layersAreOrdered = true
        lastLayer = nil
    }
}

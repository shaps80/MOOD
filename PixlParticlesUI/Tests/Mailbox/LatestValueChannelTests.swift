import Dispatch
import Synchronization
import Testing
@testable import ParticleMailbox

struct LatestValueChannelTests {
    @Test func coalescesWithoutWaitingForConsumer() {
        let channel = LatestValueChannel<Int>()
        #expect(channel.take() == nil)
        for value in 0..<100_000 { channel.publish(value) }
        #expect(channel.take() == 99_999)
        #expect(channel.take() == nil)
        channel.publish(100_000)
        #expect(channel.take() == 100_000)
    }

    @Test func concurrentPublicationHasCoherentMonotonicValues() {
        struct Value {
            let sequence: Int
            let inverse: Int
            let text: String
        }
        let channel = LatestValueChannel<Value>()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            for sequence in 1...50_000 {
                channel.publish(Value(sequence: sequence, inverse: ~sequence, text: String(sequence)))
            }
            group.leave()
        }
        var last = 0
        func consume() {
            guard let value = channel.take() else { return }
            #expect(value.sequence > last)
            #expect(value.inverse == ~value.sequence)
            #expect(value.text == String(value.sequence))
            last = value.sequence
        }
        while group.wait(timeout: .now()) != .success { consume() }
        consume()
        #expect(last == 50_000)
    }

    @Test func releasesOverwrittenReferencePayloads() {
        final class Counter: @unchecked Sendable {
            let count = Atomic<Int>(0)
        }
        final class Payload {
            let counter: Counter
            init(_ counter: Counter) { self.counter = counter }
            deinit { counter.count.wrappingAdd(1, ordering: .relaxed) }
        }
        let counter = Counter()
        func exercise() {
            let channel = LatestValueChannel<Payload>()
            for _ in 0..<1_000 { channel.publish(Payload(counter)) }
            _ = channel.take()
        }
        exercise()
        #expect(counter.count.load(ordering: .relaxed) == 1_000)
    }
}

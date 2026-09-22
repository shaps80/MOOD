import Dispatch
import Testing
@testable import ParticleProfiling

struct ProfileBufferTests {
    @Test func fullBufferDropsAndReusesSlots() {
        let buffer = ProfileBuffer<Int>(capacity: 2)
        buffer.record(10)
        buffer.record(20)
        buffer.record(30)
        #expect(buffer.droppedCount == 1)
        var values: [Int] = []
        buffer.drain { _, value in values.append(value) }
        #expect(values.sorted() == [10, 20])
        buffer.record(40)
        values.removeAll()
        buffer.drain { _, value in values.append(value) }
        #expect(values == [40])
        buffer.drain { _, _ in Issue.record("Sample delivered twice") }
    }

    @Test func concurrentProducersAndConsumer() {
        struct Payload: Sendable {
            let id: Int
            let inverse: Int
        }
        let buffer = ProfileBuffer<Payload>(capacity: 64)
        let group = DispatchGroup()
        let producerCount = 4
        let samplesPerProducer = 20_000
        for producer in 0..<producerCount {
            group.enter()
            DispatchQueue.global().async {
                for sample in 0..<samplesPerProducer {
                    let id = producer * samplesPerProducer + sample
                    buffer.record(Payload(id: id, inverse: ~id))
                }
                group.leave()
            }
        }
        var ids = Set<Int>()
        var sequences = Set<UInt64>()
        func drain() {
            buffer.drain { sequence, value in
                #expect(value.inverse == ~value.id)
                #expect(ids.insert(value.id).inserted)
                #expect(sequences.insert(sequence).inserted)
            }
        }
        while group.wait(timeout: .now()) != .success { drain() }
        drain()
        #expect(UInt64(ids.count) + buffer.droppedCount == UInt64(producerCount * samplesPerProducer))
    }
}

import PixlMemory
import Testing

@Layout("Buffer persistent")
struct BufferPersistent {}

@Layout("Buffer layout")
struct BufferLayout {
    @Region var integers: Int32
    @Region var bytes: RawBytes

    static func make(_ layout: inout Layout) {
        layout.reserve(\.integers, count: 8)
        layout.reserve(\.bytes, bytes: .bytes(16), alignment: .bytes(8))
    }
}

@Test
private func indexedBufferSupportsContiguousMutationAndReuse() throws {
    let arena = try Arena(
        BufferPersistent.self,
        layouts: BufferLayout.self,
        logging: .disabled
    )
    let scope = arena.acquire(BufferLayout.self)
    let buffer = scope.buffer(\.integers)

    buffer.append(1)
    buffer.append(contentsOf: [2, 3])
    buffer.append(count: 2) { Int32($0 + 1) }
    #expect(buffer.count == 5)
    #expect(buffer.withElements { Array($0) } == [1, 2, 3, 4, 5])

    buffer.replace(in: 1..<3) { Int32($0 * 10) }
    buffer.withMutableElements { elements in
        for index in elements.indices {
            elements[index] += 1
        }
    }
    #expect(buffer.withElements { Array($0) } == [2, 11, 21, 5, 6])
    #expect(scope.statistics.used == .bytes(20))
    #expect(scope.statistics.peak == .bytes(20))

    buffer.removeAll()
    #expect(buffer.count == 0)
    #expect(scope.statistics.used == .bytes(0))
    #expect(scope.statistics.peak == .bytes(20))

    buffer.append(9)
    #expect(buffer.withElements { Array($0) } == [9])
    scope.release()
}

@Test
private func rawBufferHonoursAlignmentAndSupportsByteMutation() throws {
    let arena = try Arena(
        BufferPersistent.self,
        layouts: BufferLayout.self,
        logging: .disabled
    )
    let scope = arena.acquire(BufferLayout.self)
    let buffer = scope.buffer(\.bytes)

    #expect(buffer.capacity == .bytes(16))
    buffer.append(contentsOf: [UInt8](0..<4))
    buffer.append(bytes: .bytes(4)) { destination in
        for index in destination.indices {
            destination[index] = UInt8(index + 4)
        }
    }
    #expect(buffer.count == .bytes(8))
    #expect(buffer.withBytes { Int(bitPattern: $0.baseAddress!) % 8 } == 0)
    #expect(buffer.withBytes { Array($0) } == [0, 1, 2, 3, 4, 5, 6, 7])

    buffer.replace(in: 2..<4) { destination in
        destination[0] = 20
        destination[1] = 30
    }
    buffer.withMutableBytes { bytes in
        bytes[0] = 10
    }
    #expect(buffer.withBytes { Array($0) } == [10, 1, 20, 30, 4, 5, 6, 7])
    #expect(scope.statistics.used == .bytes(8))
    #expect(scope.statistics.peak == .bytes(8))

    buffer.removeAll()
    #expect(buffer.count == .bytes(0))
    #expect(scope.statistics.used == .bytes(0))
    #expect(scope.statistics.peak == .bytes(8))
    scope.release()
}

import PixlMemory
import Testing

@Layout("Boundary layout")
struct BoundaryLayout {
    @Region var emptyValues: Int32
    @Region var exactValues: Int16
    @Region var emptyBytes: RawBytes
    @Region var exactBytes: RawBytes
    @Region(.densePool) var emptyPool: UInt32
    @Region(.densePool) var exactPool: UInt32

    static func make(_ layout: inout Layout) {
        layout.reserve(\.emptyValues, count: 0)
        layout.reserve(\.exactValues, count: 3)
        layout.reserve(\.emptyBytes, bytes: .bytes(0))
        layout.reserve(\.exactBytes, bytes: .bytes(3))
        layout.reserve(\.emptyPool, count: 0)
        layout.reserve(\.exactPool, count: 2)
    }
}

@Test
private func zeroAndExactCapacitiesBehaveAtTheirBoundary() throws {
    let arena = try Arena(
        EmptyPersistent.self,
        layouts: BoundaryLayout.self,
        logging: .disabled
    )
    let scope = arena.acquire(BoundaryLayout.self)

    let emptyValues = scope.buffer(\.emptyValues)
    #expect(emptyValues.capacity == 0)
    #expect(emptyValues.withElements { $0.count } == 0)

    let exactValues = scope.buffer(\.exactValues)
    exactValues.append(contentsOf: [1, 2, 3])
    #expect(exactValues.count == exactValues.capacity)

    let emptyBytes = scope.buffer(\.emptyBytes)
    #expect(emptyBytes.capacity == .bytes(0))
    #expect(emptyBytes.withBytes { $0.count } == 0)

    let exactBytes = scope.buffer(\.exactBytes)
    exactBytes.append(contentsOf: [1, 2, 3])
    #expect(exactBytes.count == exactBytes.capacity)

    let emptyPool = scope.pool(\.emptyPool)
    #expect(emptyPool.capacity == 0)
    #expect(emptyPool.count == 0)

    let exactPool = scope.pool(\.exactPool)
    _ = exactPool.insert(1)
    _ = exactPool.insert(2)
    #expect(exactPool.count == exactPool.capacity)
    scope.release()
}

@Layout("Aligned boundary")
private struct AlignedBoundaryLayout {
    @Region var prefix: UInt8
    @Region var alignedValue: UInt32

    static func make(_ layout: inout Layout) {
        layout.reserve(\.prefix, count: 1)
        layout.reserve(\.alignedValue, count: 1, alignment: .bytes(64))
    }
}

@Test
private func customAlignmentIsIncludedInPlacementAndReservation() throws {
    #expect(ByteCount.kilobytes(2).rawValue == 2_000)
    #expect(ByteCount.megabytes(3).rawValue == 3_000_000)

    let arena = try Arena(
        EmptyPersistent.self,
        layouts: AlignedBoundaryLayout.self,
        logging: .disabled
    )
    #expect(arena.reserved == .bytes(128))

    let scope = arena.acquire(AlignedBoundaryLayout.self)
    let aligned = scope.buffer(\.alignedValue)
    aligned.append(42)
    let address = aligned.withElements { Int(bitPattern: $0.baseAddress!) }
    #expect(address.isMultiple(of: 64))
    scope.release()
}

@testable import PixlMemory
import Testing

@Test
private func capacityDiagnosticsPreserveRawCountsBytesAndLocations() {
    let reservation = SourceLocation(fileID: "Game/Level.swift", line: 20)
    let access = SourceLocation(fileID: "Game/Loop.swift", line: 40)

    let indexed = CapacityFailure.indexedBuffer(
        region: "positions",
        operation: "append",
        capacity: 1_000,
        used: 1_000,
        required: 1_001,
        elementStride: 8,
        reservation: reservation,
        access: access
    )
    #expect(indexed.storage == .indexedBuffer)
    #expect(indexed.capacity == 1_000)
    #expect(indexed.used == 1_000)
    #expect(indexed.required == 1_001)
    #expect(indexed.additional == 1)
    #expect(indexed.reservedBytes == 8_000)
    #expect(indexed.usedBytes == 8_000)
    #expect(indexed.requiredBytes == 8_008)
    #expect(indexed.additionalBytes == 8)
    #expect(indexed.reservation == reservation)
    #expect(indexed.access == access)

    let raw = CapacityFailure.rawBuffer(
        region: "scratch",
        operation: "append",
        capacity: 16,
        used: 12,
        required: 20,
        reservation: reservation,
        access: access
    )
    #expect(raw.storage == .rawBuffer)
    #expect(raw.reservedBytes == 16)
    #expect(raw.usedBytes == 12)
    #expect(raw.requiredBytes == 20)
    #expect(raw.additional == 4)
    #expect(raw.additionalBytes == 4)

    let dense = CapacityFailure.densePool(
        region: "enemies",
        operation: "insert",
        capacity: 4,
        used: 4,
        required: 5,
        elementStride: 4,
        elementAlignment: 4,
        reservation: reservation,
        access: access
    )
    #expect(dense.storage == .densePool)
    #expect(dense.reservedBytes == 80)
    #expect(dense.usedBytes == 80)
    #expect(dense.requiredBytes == 100)
    #expect(dense.additional == 1)
    #expect(dense.additionalBytes == 20)
}

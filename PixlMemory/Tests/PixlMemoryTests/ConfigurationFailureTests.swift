import PixlMemory
import Testing

@Layout("Negative count")
private struct NegativeCountLayout {
    @Region var values: UInt32

    static func make(_ layout: inout Layout) {
        layout.reserve(\.values, count: -1)
    }
}

@Layout("Invalid alignment")
private struct InvalidAlignmentLayout {
    @Region var values: UInt32

    static func make(_ layout: inout Layout) {
        layout.reserve(\.values, count: 1, alignment: .bytes(3))
    }
}

@Layout("Overflow")
private struct OverflowLayout {
    @Region var values: SIMD4<UInt64>

    static func make(_ layout: inout Layout) {
        layout.reserve(\.values, count: .max)
    }
}

@Layout("Duplicate reservation")
private struct DuplicateReservationLayout {
    @Region var values: UInt32

    static func make(_ layout: inout Layout) {
        layout.reserve(\.values, count: 1)
        layout.reserve(\.values, count: 1)
    }
}

@Test
private func negativeReservationCountTerminatesDuringInitialization() async {
    await #expect(processExitsWith: .failure) {
        _ = try Arena(
            EmptyPersistent.self,
            layouts: NegativeCountLayout.self,
            logging: .disabled
        )
    }
}

@Test
private func invalidAlignmentTerminatesDuringInitialization() async {
    await #expect(processExitsWith: .failure) {
        _ = try Arena(
            EmptyPersistent.self,
            layouts: InvalidAlignmentLayout.self,
            logging: .disabled
        )
    }
}

@Test
private func reservationArithmeticOverflowTerminatesDuringInitialization() async {
    await #expect(processExitsWith: .failure) {
        _ = try Arena(
            EmptyPersistent.self,
            layouts: OverflowLayout.self,
            logging: .disabled
        )
    }
}

@Test
private func duplicateRegionReservationsThrowDuringInitialization() {
    #expect(throws: MemoryFailure.self) {
        try Arena(
            EmptyPersistent.self,
            layouts: DuplicateReservationLayout.self,
            logging: .disabled
        )
    }
}

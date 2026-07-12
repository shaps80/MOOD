import Atomics

final class BarrierAtomicStorage: @unchecked Sendable {
    private typealias Storage = Int.AtomicRepresentation
    private static let cacheLineSize = 128

    private let arrivalRawStorage: UnsafeMutableRawPointer
    private let generationRawStorage: UnsafeMutableRawPointer
    private let parkedRawStorage: UnsafeMutableRawPointer
    private let arrivalPointer: UnsafeMutablePointer<Storage>
    private let generationPointer: UnsafeMutablePointer<Storage>
    private let parkedPointer: UnsafeMutablePointer<Storage>

    let arrivalCount: UnsafeAtomic<Int>
    let generation: UnsafeAtomic<Int>
    let parkedWaiterCount: UnsafeAtomic<Int>

    init() {
        precondition(MemoryLayout<Storage>.stride <= Self.cacheLineSize)

        arrivalRawStorage = Self.allocateCacheLine()
        generationRawStorage = Self.allocateCacheLine()
        parkedRawStorage = Self.allocateCacheLine()

        arrivalPointer = Self.initialize(arrivalRawStorage)
        generationPointer = Self.initialize(generationRawStorage)
        parkedPointer = Self.initialize(parkedRawStorage)

        arrivalCount = UnsafeAtomic(at: arrivalPointer)
        generation = UnsafeAtomic(at: generationPointer)
        parkedWaiterCount = UnsafeAtomic(at: parkedPointer)
    }

    deinit {
        Self.destroy(arrivalPointer)
        Self.destroy(generationPointer)
        Self.destroy(parkedPointer)
        arrivalRawStorage.deallocate()
        generationRawStorage.deallocate()
        parkedRawStorage.deallocate()
    }

    private static func allocateCacheLine() -> UnsafeMutableRawPointer {
        .allocate(byteCount: cacheLineSize, alignment: cacheLineSize)
    }

    private static func initialize(
        _ storage: UnsafeMutableRawPointer
    ) -> UnsafeMutablePointer<Storage> {
        let pointer = storage.bindMemory(to: Storage.self, capacity: 1)
        pointer.initialize(to: Storage(0))
        return pointer
    }

    private static func destroy(_ pointer: UnsafeMutablePointer<Storage>) {
        _ = pointer.pointee.dispose()
        pointer.deinitialize(count: 1)
    }
}

import Atomics
import PixlMemory
import Testing

@Test
private func indexedBufferOverflowTerminatesImmediately() async {
    await #expect(processExitsWith: .failure) {
        let arena = try Arena(
            BufferPersistent.self,
            layouts: BufferLayout.self,
            logging: .disabled
        )
        let scope = arena.acquire(BufferLayout.self)
        let buffer = scope.buffer(\.integers)
        buffer.append(count: buffer.capacity + 1) { Int32($0) }
    }
}

@Test
private func rawBufferOverflowTerminatesImmediately() async {
    await #expect(processExitsWith: .failure) {
        let arena = try Arena(
            BufferPersistent.self,
            layouts: BufferLayout.self,
            logging: .disabled
        )
        let scope = arena.acquire(BufferLayout.self)
        let buffer = scope.buffer(\.bytes)
        buffer.append(bytes: .bytes(17)) { _ in }
    }
}

@Test
private func densePoolOverflowTerminatesImmediately() async {
    await #expect(processExitsWith: .failure) {
        let arena = try Arena(
            PoolPersistent.self,
            layouts: PoolLayoutFixture.self,
            logging: .disabled
        )
        let scope = arena.acquire(PoolLayoutFixture.self)
        let pool = scope.pool(\.values)
        for value in 0...pool.capacity {
            _ = pool.insert(UInt32(value))
        }
    }
}

@Test
private func accessingReleasedScopeStorageTerminatesImmediately() async {
    await #expect(processExitsWith: .failure) {
        let arena = try Arena(
            BufferPersistent.self,
            layouts: BufferLayout.self,
            logging: .disabled
        )
        let scope = arena.acquire(BufferLayout.self)
        let buffer = scope.buffer(\.integers)
        scope.release()
        buffer.append(1)
    }
}

@Test
private func conflictingWriteBorrowTerminatesInsteadOfWaiting() async {
    await #expect(processExitsWith: .failure) {
        let arena = try Arena(
            BufferPersistent.self,
            layouts: BufferLayout.self,
            logging: .disabled
        )
        let scope = arena.acquire(BufferLayout.self)
        let buffer = scope.buffer(\.integers)
        buffer.append(1)
        buffer.withElements { _ in
            buffer.append(2)
        }
    }
}

@Test
private func releasingBorrowedScopeTerminatesImmediately() async {
    await #expect(processExitsWith: .failure) {
        let arena = try Arena(
            BufferPersistent.self,
            layouts: BufferLayout.self,
            logging: .disabled
        )
        let scope = arena.acquire(BufferLayout.self)
        let buffer = scope.buffer(\.integers)
        buffer.append(1)
        let entered = ManagedAtomic(false)
        let hold = ManagedAtomic(true)
        let reader = Task.detached {
            buffer.withElements { _ in
                entered.store(true, ordering: .releasing)
                while hold.load(ordering: .acquiring) {}
            }
        }
        while !entered.load(ordering: .acquiring) {
            await Task.yield()
        }
        scope.release()
        hold.store(false, ordering: .releasing)
        await reader.value
    }
}

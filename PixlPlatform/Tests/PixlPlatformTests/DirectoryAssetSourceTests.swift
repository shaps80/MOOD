#if os(macOS)
import Foundation
import Testing
@testable import PixlMetalPlatform
@testable import PixlPlatform

private enum MonitorTestError: Error {
    case timeout
}

@Suite("Directory asset source")
struct DirectoryAssetSourceTests {
    @Test
    func readsAndReportsFileChanges() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let source = DirectoryAssetSource(path: root.path)
        let stream = try #require(source.changes)
        let path = try AssetPath("player.png")
        let changeTask = Task {
            try await nextChange(in: stream, matching: path)
        }
        try await Task.sleep(for: .milliseconds(500))

        try Data([1, 2, 3]).write(
            to: root.appendingPathComponent(path.value)
        )

        let change = try await changeTask.value
        #expect(change.path == path)
        #expect(change.kind == .created)
        #expect(try source.read(path) == [1, 2, 3])

        let modificationSource = DirectoryAssetSource(path: root.path)
        let modificationStream = try #require(
            modificationSource.changes
        )
        let modificationTask = Task {
            try await nextChange(
                in: modificationStream,
                matching: path
            )
        }
        try await Task.sleep(for: .milliseconds(500))
        try Data([4, 5, 6]).write(
            to: root.appendingPathComponent(path.value)
        )

        let modification = try await modificationTask.value
        #expect(modification.path == path)
        #expect(modification.kind != .removed)
        #expect(try modificationSource.read(path) == [4, 5, 6])
    }

    @Test
    func reportsRenameAwayAndBackAsRemovalAndCreation() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let jump = try AssetPath("jump.wav")
        let music = try AssetPath("music.wav")
        let jumpURL = root.appendingPathComponent(jump.value)
        let musicURL = root.appendingPathComponent(music.value)

        let source = DirectoryAssetSource(path: root.path)
        let stream = try #require(source.changes)
        try await Task.sleep(for: .milliseconds(500))

        let initialCreationTask = Task {
            try await nextChange(in: stream, matching: jump)
        }
        try Data([1, 2, 3]).write(to: jumpURL)
        let initialCreation = try await initialCreationTask.value
        #expect(initialCreation.kind == .created)

        let removalTask = Task {
            try await nextChange(in: stream, matching: jump)
        }
        try FileManager.default.moveItem(at: jumpURL, to: musicURL)
        let removal = try await removalTask.value
        #expect(removal.kind == .removed)

        let creationTask = Task {
            try await nextChange(in: stream, matching: jump)
        }
        try FileManager.default.moveItem(at: musicURL, to: jumpURL)
        let creation = try await creationTask.value
        #expect(creation.kind == .created)
    }

    private func nextChange(
        in stream: AsyncStream<AssetChange>,
        matching path: AssetPath
    ) async throws -> AssetChange {
        try await withThrowingTaskGroup(
            of: AssetChange.self
        ) { group in
            group.addTask {
                for await change in stream {
                    if change.path == path {
                        return change
                    }
                }
                throw MonitorTestError.timeout
            }
            group.addTask {
                try await Task.sleep(for: .seconds(2))
                throw MonitorTestError.timeout
            }

            guard let change = try await group.next() else {
                throw MonitorTestError.timeout
            }
            group.cancelAll()
            return change
        }
    }
}
#endif

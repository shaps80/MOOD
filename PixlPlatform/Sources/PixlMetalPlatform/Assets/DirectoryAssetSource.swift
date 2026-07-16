#if os(macOS)
import CoreServices
import Darwin
import Dispatch
import Foundation
import PixlPlatform

final class DirectoryAssetSource: AssetSource, @unchecked Sendable {
    let changes: AsyncStream<AssetChange>?

    private let root: URL
    private let monitor: DirectoryMonitor?

    init(path: String, sourcePath: String? = nil) {
        let url: URL
        if path.hasPrefix("/") {
            url = URL(fileURLWithPath: path)
        } else {
            guard let sourcePath,
                  let gamePath = gamePath(for: sourcePath)
            else {
                preconditionFailure(
                    "Relative asset paths require a Game source path"
                )
            }
            url = URL(fileURLWithPath: gamePath)
            .appendingPathComponent(path, isDirectory: true)
        }
        root = URL(
            fileURLWithPath: canonicalPath(url.standardizedFileURL.path),
            isDirectory: true
        )

        monitor = DirectoryMonitor(root: root)
        changes = monitor?.changes
    }

    func read(
        _ path: AssetPath
    ) throws(AssetSourceError) -> [UInt8] {
        let unresolved = root
            .appendingPathComponent(path.value, isDirectory: false)
            .standardizedFileURL
        let url = URL(
            fileURLWithPath: canonicalPath(unresolved.path)
        )

        let prefix = root.path.hasSuffix("/")
            ? root.path
            : root.path + "/"
        guard url.path.hasPrefix(prefix) else {
            throw .invalidPath(path.value)
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw .notFound(path)
        }
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            throw .unreadable(path)
        }
        return Array(data)
    }
}

private func gamePath(for sourcePath: String) -> String? {
    guard let range = sourcePath.range(
        of: "/Sources/",
        options: .backwards
    ) else {
        return nil
    }
    return String(sourcePath[..<range.lowerBound])
}

private final class DirectoryMonitor: @unchecked Sendable {
    let changes: AsyncStream<AssetChange>

    private let context: DirectoryMonitorContext
    private let stream: FSEventStreamRef

    init?(root: URL) {
        var continuation: AsyncStream<AssetChange>.Continuation!
        changes = AsyncStream(bufferingPolicy: .bufferingNewest(256)) {
            continuation = $0
        }
        context = DirectoryMonitorContext(
            root: root,
            continuation: continuation
        )

        var streamContext = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(context).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents
                | kFSEventStreamCreateFlagWatchRoot
                | kFSEventStreamCreateFlagNoDefer
                | kFSEventStreamCreateFlagUseCFTypes
        )
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            directoryEventCallback,
            &streamContext,
            [root.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.05,
            flags
        ) else {
            return nil
        }

        self.stream = stream
        FSEventStreamSetDispatchQueue(
            stream,
            DispatchQueue(label: "Pixl.AssetMonitor")
        )
        guard FSEventStreamStart(stream) else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            return nil
        }
    }

    deinit {
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        context.continuation.finish()
    }
}

private final class DirectoryMonitorContext {
    let continuation: AsyncStream<AssetChange>.Continuation

    private let prefix: String

    init(
        root: URL,
        continuation: AsyncStream<AssetChange>.Continuation
    ) {
        prefix = root.path.hasSuffix("/")
            ? root.path
            : root.path + "/"
        self.continuation = continuation
    }

    func handle(
        paths: NSArray,
        flags: UnsafePointer<FSEventStreamEventFlags>,
        count: Int
    ) {
        var index = 0
        while index < count {
            defer { index += 1 }
            guard let fullPath = paths[index] as? String,
                  fullPath.hasPrefix(prefix),
                  isFile(flags[index])
            else {
                continue
            }

            let value = String(fullPath.dropFirst(prefix.count))
            guard let path = try? AssetPath(value) else { continue }
            continuation.yield(
                AssetChange(
                    path: path,
                    kind: kind(for: flags[index], path: fullPath)
                )
            )
        }
    }

    private func isFile(
        _ flags: FSEventStreamEventFlags
    ) -> Bool {
        flags & FSEventStreamEventFlags(
            kFSEventStreamEventFlagItemIsFile
        ) != 0
    }

    private func kind(
        for flags: FSEventStreamEventFlags,
        path: String
    ) -> AssetChange.Kind {
        if flags & FSEventStreamEventFlags(
            kFSEventStreamEventFlagItemRemoved
        ) != 0 {
            return .removed
        }
        if flags & FSEventStreamEventFlags(
            kFSEventStreamEventFlagItemCreated
        ) != 0 {
            return .created
        }
        if flags & FSEventStreamEventFlags(
            kFSEventStreamEventFlagItemRenamed
        ) != 0 {
            return FileManager.default.fileExists(atPath: path)
                ? .created
                : .removed
        }
        return .modified
    }
}

private let directoryEventCallback: FSEventStreamCallback = {
    _, info, count, eventPaths, flags, _ in
    guard let info else { return }
    let context = Unmanaged<DirectoryMonitorContext>
        .fromOpaque(info)
        .takeUnretainedValue()
    let paths = unsafeBitCast(eventPaths, to: NSArray.self)
    context.handle(paths: paths, flags: flags, count: count)
}

private func canonicalPath(_ path: String) -> String {
    path.withCString { path in
        guard let resolved = realpath(path, nil) else {
            return String(cString: path)
        }
        defer { free(resolved) }
        return String(cString: resolved)
    }
}
#endif

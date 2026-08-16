import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension ParticleDocument: ReadableDocument {
    static var readableContentTypes: [UTType] { [.pixlParticles] }

    func apply(
        snapshot: sending Snapshot,
        previous: sending Snapshot?
    ) async throws {
        guard snapshot != previous else { return }
        replace(with: snapshot)
    }

    func reader(configuration: sending ReadConfiguration) -> Reader {
        .init()
    }

    final class Reader: DocumentReader<Snapshot> {
        func read(
            from source: sending URL,
            progress: consuming Subprogress
        ) async throws -> Snapshot {
            let data = try Data(contentsOf: source, options: .mappedIfSafe)
            return try JSONDecoder().decode(Snapshot.self, from: data)
        }
    }
}

extension ParticleDocument: WritableDocument {
    static var writableContentTypes: [UTType] { [.pixlParticles] }

    func snapshot(contentType: UTType) async throws -> sending Snapshot {
        snapshot
    }

    func writer(configuration: sending WriteConfiguration) -> Writer {
        .init()
    }

    final class Writer: DocumentWriter<Snapshot> {
        func write(
            snapshot: sending Snapshot,
            to destination: sending URL,
            previous: sending Snapshot?,
            progress: consuming Subprogress
        ) async throws {
            guard snapshot != previous else { return }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(snapshot).write(to: destination, options: .atomic)
        }
    }
}

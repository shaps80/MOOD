import Foundation
import Swift

final class AssetResolver {
    private let fileManager = FileManager.default
    private lazy var searchRoots: [URL] = makeSearchRoots()

    func url(for assetPath: String) -> URL? {
        for root in searchRoots {
            let directURL = root.appendingPathComponent(assetPath)
            if fileManager.fileExists(atPath: directURL.path) {
                return directURL
            }

            let gameURL = root
                .appendingPathComponent("Game")
                .appendingPathComponent(assetPath)
            if fileManager.fileExists(atPath: gameURL.path) {
                return gameURL
            }
        }

        return nil
    }

    private func makeSearchRoots() -> [URL] {
        var roots = [URL]()

        if let resourceURL = Bundle.main.resourceURL {
            roots.append(resourceURL)
        }

        roots.append(Bundle.main.bundleURL)

        roots.append(
            URL(
                fileURLWithPath: fileManager.currentDirectoryPath,
                isDirectory: true
            )
        )

        if let executablePath = CommandLine.arguments.first {
            roots.append(
                URL(fileURLWithPath: executablePath)
                    .deletingLastPathComponent()
            )
        }

        let directRoots = roots
        for root in directRoots {
            roots.append(contentsOf: resourceBundleRoots(near: root))
        }

        return expandedAncestorRoots(from: roots)
    }

    private func resourceBundleRoots(near root: URL) -> [URL] {
        guard let children = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        var roots = [URL]()

        for child in children where child.pathExtension == "bundle" {
            if let resourceURL = Bundle(url: child)?.resourceURL {
                roots.append(resourceURL)
            }

            roots.append(child)
        }

        return roots
    }

    private func expandedAncestorRoots(from roots: [URL]) -> [URL] {
        var expandedRoots = [URL]()
        var seenPaths = Set<String>()

        for root in roots {
            var current = root.standardizedFileURL

            for _ in 0..<8 {
                if seenPaths.insert(current.path).inserted {
                    expandedRoots.append(current)
                }

                let parent = current.deletingLastPathComponent()
                guard parent.path != current.path else { break }

                current = parent
            }
        }

        return expandedRoots
    }
}

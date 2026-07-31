import Foundation
import PixlText

struct PlaygroundFont: Hashable, Identifiable, Sendable {
    let name: String
    let path: String

    var id: String { path }

    static let zapfino = Self(
        name: "Zapfino",
        path: "/System/Library/Fonts/Supplemental/Zapfino.ttf"
    )

    static let senilita = Self(
        name: "Senilita",
        path: "/Users/shaps/Library/Fonts/Senilita.otf"
    )

    static let sfPro = Self(
        name: "SF Pro Variable",
        path: "/Library/Fonts/SF-Pro.ttf"
    )

    static let initial = [sfPro, senilita, zapfino]

    func loadBytes() throws -> [UInt8] {
        Array(try Data(contentsOf: URL(filePath: path)))
    }

    static func installed() -> [Self] {
        let roots = [
            URL(filePath: "/System/Library/Fonts"),
            URL(filePath: "/Library/Fonts"),
            FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Fonts")
        ]
        let supportedExtensions = Set(["ttf", "otf"])
        var fonts: [Self] = []

        for root in roots {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let url as URL in enumerator
                where supportedExtensions.contains(url.pathExtension.lowercased()) {
                let font: Self? = autoreleasepool {
                    guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
                        return nil
                    }
                    guard PixlText.Font.supportsFont(bytes: Array(data)) else {
                        return nil
                    }
                    return Self(
                        name: url.deletingPathExtension().lastPathComponent,
                        path: url.path
                    )
                }
                if let font {
                    fonts.append(font)
                }
            }
        }

        return Dictionary(fonts.map { ($0.path, $0) }) { first, _ in first }
            .values
            .sorted {
                let order = $0.name.localizedStandardCompare($1.name)
                return order == .orderedSame ? $0.path < $1.path : order == .orderedAscending
            }
    }
}

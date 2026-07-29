#if os(macOS)
import Foundation
import Testing
@testable import PixlText

@Suite("Installed font corpus")
struct InstalledFontCorpusTests {
    @Test("Every installed standalone SFNT face registers")
    func registrationCorpus() throws {
        let urls = installedFontURLs().filter {
            $0.pathExtension.lowercased() == "ttf"
                || $0.pathExtension.lowercased() == "otf"
        }
        var failures: [String] = []
        var unsupported = 0

        for url in urls {
            do {
                let bytes = Array(try Data(contentsOf: url, options: .mappedIfSafe))
                _ = try SFNT.Registry().register(bytes: bytes)
            } catch SFNT.RegistrationError.unsupportedCharacterMap,
                    SFNT.RegistrationError.missingRequiredTable {
                unsupported += 1
            } catch {
                failures.append("\(url.path): \(error) [\(shapingTableDiagnosis(bytesAt: url))]")
            }
        }

        print("Font corpus: \(urls.count - unsupported) supported, \(unsupported) known capability gaps")
        #expect(
            failures.isEmpty,
            Comment(rawValue: "\(failures.count)/\(urls.count) fonts failed:\n\(failures.joined(separator: "\n"))")
        )
    }

    @Test("Senilita matches HarfBuzz for supported Latin shaping")
    func harfBuzzDifferential() throws {
        let executable = URL(filePath: "/opt/homebrew/bin/hb-shape")
        let font = URL(filePath: "/Users/shaps/Library/Fonts/Senilita.otf")
        guard FileManager.default.isExecutableFile(atPath: executable.path),
              FileManager.default.fileExists(atPath: font.path)
        else { return }

        let bytes = Array(try Data(contentsOf: font, options: .mappedIfSafe))
        for text in ["Hello, world!", "AVATAR To Wa", "office file"] {
            let expected = try harfBuzzShape(executable: executable, font: font, text: text)
            let actual = try shape(bytes: bytes, text: text)
            #expect(actual == expected, "Mismatch for \(String(reflecting: text))")
        }
    }

    private struct PositionedGlyph: Codable, Equatable {
        let g: UInt16
        let cl: Int
        let dx: Int32
        let dy: Int32
        let ax: Int32
        let ay: Int32
    }

    private func shape(bytes: [UInt8], text: String) throws -> [PositionedGlyph] {
        let registry = SFNT.Registry()
        let face = try registry.register(bytes: bytes)
        var glyphs = GlyphBuffer(minimumCapacity: text.unicodeScalars.count)
        var sourceOffset = 0
        for scalar in text.unicodeScalars {
            let length = scalar.utf8.count
            glyphs.append(.init(
                id: registry.glyphID(for: scalar, in: face) ?? .init(rawValue: 0),
                sourceRange: sourceOffset..<(sourceOffset + length),
                lookupIndex: nil,
                feature: nil
            ))
            sourceOffset += length
        }

        let latin: UInt32 = 0x6C61_746E
        if let substitution = registry.glyphSubstitution(in: face) {
            OpenTypeShaper.apply(substitution.shapingPlan(script: latin), to: &glyphs)
        }
        if let positioning = registry.glyphPositioning(in: face) {
            OpenTypePositioner.apply(positioning.positioningPlan(script: latin), to: &glyphs)
        }

        return try (0..<glyphs.count).map { index in
            let glyph = glyphs[index]
            let baseAdvance = try #require(registry.advance(
                for: glyph.id,
                in: face,
                size: Float(face.metrics.unitsPerEm)
            ))
            return .init(
                g: glyph.id.rawValue,
                cl: glyph.sourceRange.lowerBound,
                dx: glyph.xPlacement,
                dy: glyph.yPlacement,
                ax: Int32(baseAdvance) + glyph.xAdvance,
                ay: glyph.yAdvance
            )
        }
    }

    private func harfBuzzShape(
        executable: URL,
        font: URL,
        text: String
    ) throws -> [PositionedGlyph] {
        let process = Process()
        let output = Pipe()
        process.executableURL = executable
        process.arguments = [
            font.path,
            text,
            "--output-format=json",
            "--no-glyph-names",
            "--features=ccmp,locl,rlig,liga,clig,calt,kern,dist"
        ]
        process.standardOutput = output
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CorpusError.harfBuzzFailed(process.terminationStatus)
        }
        return try JSONDecoder().decode(
            [PositionedGlyph].self,
            from: output.fileHandleForReading.readDataToEndOfFile()
        )
    }

    private func installedFontURLs() -> [URL] {
        let roots = [
            URL(filePath: "/System/Library/Fonts"),
            URL(filePath: "/Library/Fonts"),
            FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Fonts")
        ]
        let extensions = Set(["ttf", "otf", "ttc"])
        var result: [URL] = []
        for root in roots {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for case let url as URL in enumerator
                where extensions.contains(url.pathExtension.lowercased()) {
                result.append(url)
            }
        }
        return result.sorted { $0.path < $1.path }
    }

    private func shapingTableDiagnosis(bytesAt url: URL) -> String {
        guard let bytes = try? Array(Data(contentsOf: url, options: .mappedIfSafe)) else {
            return "unreadable"
        }
        var results: [String] = []
        for (name, tag) in [("GSUB", UInt32(0x4753_5542)), ("GPOS", UInt32(0x4750_4F53))] {
            guard let table = table(tag: tag, bytes: bytes) else {
                results.append("\(name):none")
                continue
            }
            do {
                if name == "GSUB" {
                    _ = try SFNT.GlyphSubstitution.parse(table: table, bytes: bytes)
                } else {
                    _ = try SFNT.GlyphPositioning.parse(table: table, bytes: bytes)
                }
                results.append("\(name):ok")
            } catch {
                results.append("\(name):\(error)")
            }
        }
        return results.joined(separator: ", ")
    }

    private func table(tag: UInt32, bytes: [UInt8]) -> SFNT.Table? {
        guard bytes.count >= 12 else { return nil }
        let count = Int(uint16(bytes, at: 4))
        guard 12 + count * 16 <= bytes.count else { return nil }
        for index in 0..<count {
            let record = 12 + index * 16
            guard uint32(bytes, at: record) == tag else { continue }
            let offset = Int(uint32(bytes, at: record + 8))
            let length = Int(uint32(bytes, at: record + 12))
            guard offset <= bytes.count - length else { return nil }
            return .init(offset: offset, length: length)
        }
        return nil
    }

    private func uint16(_ bytes: [UInt8], at offset: Int) -> UInt16 {
        UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
    }

    private func uint32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        UInt32(bytes[offset]) << 24
            | UInt32(bytes[offset + 1]) << 16
            | UInt32(bytes[offset + 2]) << 8
            | UInt32(bytes[offset + 3])
    }

    private enum CorpusError: Error {
        case harfBuzzFailed(Int32)
    }
}
#endif

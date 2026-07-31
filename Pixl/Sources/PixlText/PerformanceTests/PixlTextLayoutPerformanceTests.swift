#if PIXL_TEXT_PERFORMANCE_TESTS
import Foundation
import PixlText

@main
struct PixlTextLayoutPerformanceTests {
    private struct Configuration {
        var size: Float
        var weight: Float?
        var style: ParagraphStyle
    }

    private struct Statistics {
        let medianMilliseconds: Double
        let averageMilliseconds: Double
        let maximumMilliseconds: Double
    }

    private static let layoutBudgetMilliseconds = 16.667
    private static let iterationCount = 25
    private static let fontPath = "/Library/Fonts/SF-Pro.ttf"
    private static let paragraphs = [
        "Hello, world! Line breaking finds every legal opportunity before layout chooses which words fit. Explicit newlines remain mandatory.",
        "A second paragraph has enough text to wrap independently. Its lines share paragraph geometry while retaining direct glyph ranges.",
        "The final paragraph makes paragraph spacing and first and last baselines easy to inspect without introducing any presentation rules."
    ]
    private static let text = paragraphs.joined(separator: "\n")
    private static let paragraphRanges: [Range<Int>] = {
        var offset = 0
        return paragraphs.indices.map { index in
            let upperBound = offset
                + paragraphs[index].utf8.count
                + (index + 1 < paragraphs.count ? 1 : 0)
            defer { offset = upperBound }
            return offset..<upperBound
        }
    }()

    static func main() throws {
        let bytes = Array(try Data(contentsOf: URL(filePath: fontPath)))
        let session = Font.LayoutDebugSession()
        let baseline = configurations()

        let warm = try layout(baseline, bytes: bytes, session: session)
        precondition(warm.runs.count == 3)
        precondition(warm.paragraphs.count == 3)
        try validateVariableWeight(bytes: bytes, session: session, baseline: baseline)

        try test("unchanged layout", bytes: bytes, session: session) { _ in baseline }
        try test("paragraph alignment", bytes: bytes, session: session) { iteration in
            var value = baseline
            value[1].style.alignment = iteration.isMultiple(of: 2) ? .leading : .center
            return value
        }
        try test("font size", bytes: bytes, session: session) { iteration in
            var value = baseline
            value[1].size = iteration.isMultiple(of: 2) ? 20 : 20.5
            return value
        }
        try test("variable weight", bytes: bytes, session: session) { iteration in
            var value = baseline
            value[1].weight = Float(250 + iteration * 25)
            return value
        }
    }

    private static func validateVariableWeight(
        bytes: [UInt8],
        session: Font.LayoutDebugSession,
        baseline: [Configuration]
    ) throws {
        var light = baseline
        light[1].weight = 250
        var heavy = baseline
        heavy[1].weight = 850
        let lightLayout = try layout(light, bytes: bytes, session: session)
        let heavyLayout = try layout(heavy, bytes: bytes, session: session)
        precondition(lightLayout.runs.count == heavyLayout.runs.count)
        precondition(zip(lightLayout.runs, heavyLayout.runs).contains { light, heavy in
            light.bounds.width != heavy.bounds.width
        })
    }

    private static func test(
        _ name: String,
        bytes: [UInt8],
        session: Font.LayoutDebugSession,
        configurations: (Int) -> [Configuration]
    ) throws {
        let statistics = try measure(iterations: iterationCount) { iteration in
            try layout(configurations(iteration), bytes: bytes, session: session)
        }
        print(
            "\(name): median \(statistics.medianMilliseconds) ms, "
                + "average \(statistics.averageMilliseconds) ms, "
                + "max \(statistics.maximumMilliseconds) ms"
        )
        precondition(
            statistics.medianMilliseconds <= layoutBudgetMilliseconds,
            "\(name) exceeded the \(layoutBudgetMilliseconds) ms median layout budget"
        )
    }

    private static func measure(
        iterations: Int,
        operation: (Int) throws -> Font.LayoutDebugInfo
    ) throws -> Statistics {
        let clock = ContinuousClock()
        var samples: [Double] = []
        var checksum: Float = 0
        samples.reserveCapacity(iterations)
        for iteration in 0..<iterations {
            let start = clock.now
            let result = try operation(iteration)
            let duration = start.duration(to: clock.now)
            samples.append(
                Double(duration.components.seconds) * 1_000
                    + Double(duration.components.attoseconds) / 1e15
            )
            checksum += result.runs.reduce(into: 0) { $0 += $1.bounds.width }
            precondition(result.paragraphs.count == 3)
        }
        precondition(checksum > 0)
        samples.sort()
        return .init(
            medianMilliseconds: samples[samples.count / 2],
            averageMilliseconds: samples.reduce(0, +) / Double(samples.count),
            maximumMilliseconds: samples.last ?? 0
        )
    }

    private static func layout(
        _ configurations: [Configuration],
        bytes: [UInt8],
        session: Font.LayoutDebugSession
    ) throws -> Font.LayoutDebugInfo {
        let base = configurations[0]
        let input = Font.LayoutDebugInfo.FontInput(
            font: font(for: base),
            fontBytes: bytes,
            fontID: fontPath
        )
        let overrides: [Font.LayoutDebugInfo.Input] = zip(
            paragraphRanges,
            configurations
        ).compactMap { range, configuration -> Font.LayoutDebugInfo.Input? in
            guard configuration.size != base.size || configuration.weight != base.weight else {
                return nil
            }
            return .init(
                sourceRange: range,
                font: .init(
                    font: font(for: configuration),
                    fontBytes: bytes,
                    fontID: fontPath
                )
            )
        }
        return try session.layout(
            text,
            font: input,
            overrides: overrides,
            constraints: .init(width: 520),
            lineHeight: .multiple(1.35),
            paragraphStyles: configurations.map(\.style)
        )
    }

    private static func configurations() -> [Configuration] {
        [
            .init(
                size: 24,
                style: .init(spacing: .init(lineSpacing: 8, paragraphAfter: 28))
            ),
            .init(
                size: 20,
                style: .init(spacing: .init(lineSpacing: 8, paragraphAfter: 28))
            ),
            .init(
                size: 22,
                style: .init(spacing: .init(lineSpacing: 8, paragraphAfter: 28))
            )
        ]
    }

    private static func font(for configuration: Configuration) -> Font {
        let font = Font.system(size: configuration.size)
        return configuration.weight.map { font.variation("wght", value: $0) } ?? font
    }
}
#endif

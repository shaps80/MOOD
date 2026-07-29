#if !os(WASI)
import XCTest
@testable import PixlText

final class OpenTypeShapingPerformanceTests: XCTestCase {
    func testColdPlanCompilationPerformance() {
        let substitutions = makeSubstitutions()
        var checksum = 0

        measure(metrics: metrics, options: automaticOptions) {
            let plan = substitutions.shapingPlan(script: latin)
            checksum &+= plan.lookups.count
            checksum &+= plan.singleRules.count
            checksum &+= plan.ligatureRules.count
        }

        XCTAssertNotEqual(checksum, 0)
    }

    func testHotShaping10KPerformance() {
        measureHotShaping(glyphCount: 10_000)
    }

    func testHotShaping100KPerformance() {
        measureHotShaping(glyphCount: 100_000)
    }

    private func measureHotShaping(glyphCount: Int) {
        let plan = makeSubstitutions().shapingPlan(script: latin)
        let source = makeGlyphs(count: glyphCount)
        var glyphs: [ShapingGlyph] = []
        glyphs.reserveCapacity(source.count)
        var checksum = 0

        measure(metrics: metrics, options: manualOptions) {
            glyphs.removeAll(keepingCapacity: true)
            glyphs.append(contentsOf: source)

            startMeasuring()
            OpenTypeShaper.apply(plan, to: &glyphs)
            stopMeasuring()

            checksum &+= glyphs.count
        }

        XCTAssertNotEqual(checksum, 0)
        XCTAssertLessThan(glyphs.count, source.count)
    }

    private var metrics: [any XCTMetric] {
        [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]
    }

    private var automaticOptions: XCTMeasureOptions {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        return options
    }

    private var manualOptions: XCTMeasureOptions {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        options.invocationOptions = [.manuallyStart, .manuallyStop]
        return options
    }

    private var latin: UInt32 { 0x6C61_746E }

    private func makeGlyphs(count: Int) -> [ShapingGlyph] {
        (0..<count).map { index in
            .init(
                id: .init(rawValue: UInt16(index & 255)),
                sourceRange: index..<(index + 1),
                lookupIndex: nil,
                feature: nil
            )
        }
    }

    private func makeSubstitutions() -> SFNT.GlyphSubstitution {
        var rules: [SFNT.GlyphSubstitution.Substitution] = (0..<512).map {
            .single(input: UInt16($0), output: UInt16($0))
        }
        for value in stride(from: 0, to: 128, by: 2) {
            rules.append(.ligature(
                components: [UInt16(value), UInt16(value + 1)],
                output: UInt16(1_000 + value / 2)
            ))
        }

        return .init(
            scripts: [
                .init(
                    tag: latin,
                    defaultLanguage: .init(
                        requiredFeatureIndex: nil,
                        featureIndices: [0]
                    ),
                    languages: []
                )
            ],
            features: [
                .init(tag: 0x6C69_6761, lookupIndices: [0])
            ],
            lookups: [
                .init(index: 0, substitutions: rules)
            ]
        )
    }
}
#endif

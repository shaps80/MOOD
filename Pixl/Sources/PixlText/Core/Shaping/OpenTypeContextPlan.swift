struct OpenTypeContextPlan {
    struct Rule {
        let firstMatcher: Int?
        let backtrack: Range<Int>
        let input: Range<Int>
        let lookahead: Range<Int>
        let actions: Range<Int>
    }

    struct Matcher {
        enum Kind {
            case glyph
            case coverage
            case glyphClass
        }

        let kind: Kind
        let dataIndex: Int
        let value: UInt16
    }

    struct Action {
        let sequenceIndex: Int
        let lookupIndex: Int
    }

    struct ClassRange {
        let glyphs: ClosedRange<UInt16>
        let value: UInt16
    }

    let rules: [Rule]
    let matchers: [Matcher]
    let actions: [Action]
    let coverages: [Range<Int>]
    let coverageGlyphs: [UInt16]
    let classDefinitions: [Range<Int>]
    let classRanges: [ClassRange]

    func matches(_ matcherIndex: Int, glyph: UInt16) -> Bool {
        let matcher = matchers[matcherIndex]
        switch matcher.kind {
        case .glyph:
            return matcher.value == glyph
        case .coverage:
            return contains(glyph, in: coverages[matcher.dataIndex])
        case .glyphClass:
            return classValue(glyph, in: classDefinitions[matcher.dataIndex]) == matcher.value
        }
    }

    func coverageIndex(of glyph: UInt16, coverage index: Int) -> Int? {
        let range = coverages[index]
        var lower = range.lowerBound
        var upper = range.upperBound
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if coverageGlyphs[middle] < glyph {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        guard lower < range.upperBound, coverageGlyphs[lower] == glyph else { return nil }
        return lower - range.lowerBound
    }

    private func contains(_ glyph: UInt16, in range: Range<Int>) -> Bool {
        var lower = range.lowerBound
        var upper = range.upperBound
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if coverageGlyphs[middle] < glyph {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower < range.upperBound && coverageGlyphs[lower] == glyph
    }

    private func classValue(_ glyph: UInt16, in range: Range<Int>) -> UInt16 {
        var lower = range.lowerBound
        var upper = range.upperBound
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if classRanges[middle].glyphs.upperBound < glyph {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        guard lower < range.upperBound, classRanges[lower].glyphs.contains(glyph) else { return 0 }
        return classRanges[lower].value
    }
}

struct OpenTypeContextPlanBuilder {
    private(set) var rules: [OpenTypeContextPlan.Rule] = []
    private(set) var matchers: [OpenTypeContextPlan.Matcher] = []
    private(set) var actions: [OpenTypeContextPlan.Action] = []
    private(set) var coverages: [Range<Int>] = []
    private(set) var coverageGlyphs: [UInt16] = []
    private(set) var classDefinitions: [Range<Int>] = []
    private(set) var classRanges: [OpenTypeContextPlan.ClassRange] = []

    private var coverageIndices: [SFNT.OpenTypeLayout.Coverage: Int] = [:]
    private var classIndices: [SFNT.OpenTypeLayout.ClassDefinition: Int] = [:]

    mutating func append(_ source: SFNT.OpenTypeLayout.ContextRule) -> Int {
        let firstMatcher = source.firstCoverage.map {
            append(.coverage($0))
        }
        let backtrack = append(source.backtrack)
        let input = append(source.input)
        let lookahead = append(source.lookahead)
        let actionLower = actions.count
        actions.append(contentsOf: source.actions.map {
            .init(sequenceIndex: $0.sequenceIndex, lookupIndex: $0.lookupIndex)
        })
        let index = rules.count
        rules.append(.init(
            firstMatcher: firstMatcher,
            backtrack: backtrack,
            input: input,
            lookahead: lookahead,
            actions: actionLower..<actions.count
        ))
        return index
    }

    mutating func appendCoverage(_ source: SFNT.OpenTypeLayout.Coverage) -> Int {
        if let index = coverageIndices[source] { return index }
        let lower = coverageGlyphs.count
        coverageGlyphs.append(contentsOf: source.glyphs)
        let index = coverages.count
        coverages.append(lower..<coverageGlyphs.count)
        coverageIndices[source] = index
        return index
    }

    func build() -> OpenTypeContextPlan {
        .init(
            rules: rules,
            matchers: matchers,
            actions: actions,
            coverages: coverages,
            coverageGlyphs: coverageGlyphs,
            classDefinitions: classDefinitions,
            classRanges: classRanges
        )
    }

    private mutating func append(
        _ sources: [SFNT.OpenTypeLayout.Matcher]
    ) -> Range<Int> {
        let lower = matchers.count
        for source in sources { _ = append(source) }
        return lower..<matchers.count
    }

    private mutating func append(_ source: SFNT.OpenTypeLayout.Matcher) -> Int {
        let matcher: OpenTypeContextPlan.Matcher
        switch source {
        case .glyph(let glyph):
            matcher = .init(kind: .glyph, dataIndex: 0, value: glyph)
        case .coverage(let coverage):
            matcher = .init(
                kind: .coverage,
                dataIndex: appendCoverage(coverage),
                value: 0
            )
        case .glyphClass(let definition, let value):
            matcher = .init(
                kind: .glyphClass,
                dataIndex: appendClassDefinition(definition),
                value: value
            )
        }
        let index = matchers.count
        matchers.append(matcher)
        return index
    }

    private mutating func appendClassDefinition(
        _ source: SFNT.OpenTypeLayout.ClassDefinition
    ) -> Int {
        if let index = classIndices[source] { return index }
        let lower = classRanges.count
        classRanges.append(contentsOf: source.ranges.map {
            .init(glyphs: $0.glyphs, value: $0.value)
        })
        let index = classDefinitions.count
        classDefinitions.append(lower..<classRanges.count)
        classIndices[source] = index
        return index
    }
}

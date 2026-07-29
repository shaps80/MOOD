struct OpenTypePositioningPlan {
    struct Lookup {
        let sourceIndex: Int
        let feature: UInt32
        let subtables: Range<Int>
    }

    enum Subtable {
        case glyphPairs(Range<Int>)
        case classPairs(Int)
    }

    struct PairRule {
        let key: UInt32
        let first: SFNT.GlyphPositioning.ValueAdjustment
        let second: SFNT.GlyphPositioning.ValueAdjustment
    }

    let lookups: [Lookup]
    let subtables: [Subtable]
    let pairRules: [PairRule]
    let classTables: [SFNT.GlyphPositioning.ClassPairTable]
}

extension SFNT.GlyphPositioning {
    func positioningPlan(
        script scriptTag: UInt32,
        language languageTag: UInt32? = nil
    ) -> OpenTypePositioningPlan {
        var lookups: [OpenTypePositioningPlan.Lookup] = []
        var subtables: [OpenTypePositioningPlan.Subtable] = []
        var pairRules: [OpenTypePositioningPlan.PairRule] = []
        var classTables: [ClassPairTable] = []

        for active in activeLookups(script: scriptTag, language: languageTag) {
            let lower = subtables.count
            for pair in active.lookup.pairs {
                switch pair {
                case .glyphs(let rules):
                    let ruleLower = pairRules.count
                    pairRules.append(contentsOf: rules.map {
                        .init(
                            key: UInt32($0.first) << 16 | UInt32($0.second),
                            first: $0.firstAdjustment,
                            second: $0.secondAdjustment
                        )
                    }.sorted { $0.key < $1.key })
                    subtables.append(.glyphPairs(ruleLower..<pairRules.count))

                case .classes(let table):
                    let index = classTables.count
                    classTables.append(table)
                    subtables.append(.classPairs(index))
                }
            }
            if lower < subtables.count {
                lookups.append(.init(
                    sourceIndex: active.lookup.index,
                    feature: active.feature,
                    subtables: lower..<subtables.count
                ))
            }
        }
        return .init(
            lookups: lookups,
            subtables: subtables,
            pairRules: pairRules,
            classTables: classTables
        )
    }
}

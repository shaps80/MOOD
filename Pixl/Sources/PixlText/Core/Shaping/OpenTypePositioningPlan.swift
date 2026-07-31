struct OpenTypePositioningPlan {
    struct Execution {
        let lookupIndex: Int
        let feature: UInt32
    }

    struct Lookup {
        let sourceIndex: Int
        let flags: SFNT.OpenTypeLayout.LookupFlags
        let subtables: Range<Int>
    }

    enum Subtable {
        case single(Range<Int>)
        case glyphPairs(Range<Int>)
        case classPairs(Int)
        case cursive(Range<Int>)
        case markToBase(Int)
        case markToLigature(Int)
        case markToMark(Int)
        case context(Range<Int>)
    }

    struct SingleRule {
        let glyph: UInt16
        let adjustment: SFNT.GlyphPositioning.ValueAdjustment
    }

    struct PairRule {
        let key: UInt32
        let first: SFNT.GlyphPositioning.ValueAdjustment
        let second: SFNT.GlyphPositioning.ValueAdjustment
    }

    struct CursiveRule {
        let glyph: UInt16
        let entry: SFNT.OpenTypeLayout.Anchor?
        let exit: SFNT.OpenTypeLayout.Anchor?
    }

    struct MarkRule {
        let glyph: UInt16
        let markClass: Int
        let anchor: SFNT.OpenTypeLayout.Anchor
    }

    struct BaseRule {
        let glyph: UInt16
        let anchors: Range<Int>
    }

    struct MarkBaseTable {
        let marks: Range<Int>
        let bases: Range<Int>
        let classCount: Int
    }

    struct LigatureRule {
        let glyph: UInt16
        let components: Range<Int>
    }

    struct LigatureComponent {
        let anchors: Range<Int>
    }

    struct MarkLigatureTable {
        let marks: Range<Int>
        let ligatures: Range<Int>
        let classCount: Int
    }

    let executions: [Execution]
    let lookups: [Lookup]
    let subtables: [Subtable]
    let singleRules: [SingleRule]
    let pairRules: [PairRule]
    let classTables: [SFNT.GlyphPositioning.ClassPairTable]
    let cursiveRules: [CursiveRule]
    let markRules: [MarkRule]
    let baseRules: [BaseRule]
    let anchors: [SFNT.OpenTypeLayout.Anchor?]
    let markBaseTables: [MarkBaseTable]
    let ligatureRules: [LigatureRule]
    let ligatureComponents: [LigatureComponent]
    let markLigatureTables: [MarkLigatureTable]
    let context: OpenTypeContextPlan
}

extension SFNT.GlyphPositioning {
    func positioningPlan(
        script scriptTag: UInt32,
        language languageTag: UInt32? = nil,
        coordinates: [Float] = [],
        variationStore: SFNT.ItemVariationStore? = nil
    ) -> OpenTypePositioningPlan {
        let active = activeLookups(
            script: scriptTag,
            language: languageTag,
            coordinates: coordinates
        )
        var plannedLookups: [OpenTypePositioningPlan.Lookup] = []
        var subtables: [OpenTypePositioningPlan.Subtable] = []
        var singleRules: [OpenTypePositioningPlan.SingleRule] = []
        var pairRules: [OpenTypePositioningPlan.PairRule] = []
        var classTables: [ClassPairTable] = []
        var cursiveRules: [OpenTypePositioningPlan.CursiveRule] = []
        var markRules: [OpenTypePositioningPlan.MarkRule] = []
        var baseRules: [OpenTypePositioningPlan.BaseRule] = []
        var anchors: [SFNT.OpenTypeLayout.Anchor?] = []
        var markBaseTables: [OpenTypePositioningPlan.MarkBaseTable] = []
        var ligatureRules: [OpenTypePositioningPlan.LigatureRule] = []
        var ligatureComponents: [OpenTypePositioningPlan.LigatureComponent] = []
        var markLigatureTables: [OpenTypePositioningPlan.MarkLigatureTable] = []
        var contextBuilder = OpenTypeContextPlanBuilder()
        func resolved(_ value: ValueAdjustment) -> ValueAdjustment {
            value.resolved(store: variationStore, coordinates: coordinates)
        }
        func resolved(_ anchor: SFNT.OpenTypeLayout.Anchor) -> SFNT.OpenTypeLayout.Anchor {
            anchor.resolved(store: variationStore, coordinates: coordinates)
        }

        plannedLookups.reserveCapacity(lookups.count)
        for lookup in lookups {
            let lower = subtables.count
            for subtable in lookup.subtables {
                switch subtable {
                case .single(let rules):
                    let ruleLower = singleRules.count
                    singleRules.append(contentsOf: rules.map {
                        .init(glyph: $0.glyph, adjustment: resolved($0.adjustment))
                    }.sorted { $0.glyph < $1.glyph })
                    subtables.append(.single(ruleLower..<singleRules.count))

                case .pair(.glyphs(let rules)):
                    let ruleLower = pairRules.count
                    pairRules.append(contentsOf: rules.map {
                        .init(
                            key: UInt32($0.first) << 16 | UInt32($0.second),
                            first: resolved($0.firstAdjustment),
                            second: resolved($0.secondAdjustment)
                        )
                    }.sorted { $0.key < $1.key })
                    subtables.append(.glyphPairs(ruleLower..<pairRules.count))

                case .pair(.classes(let table)):
                    let index = classTables.count
                    classTables.append(.init(
                        coverage: table.coverage,
                        firstClasses: table.firstClasses,
                        secondClasses: table.secondClasses,
                        firstClassCount: table.firstClassCount,
                        secondClassCount: table.secondClassCount,
                        firstAdjustments: table.firstAdjustments.map(resolved),
                        secondAdjustments: table.secondAdjustments.map(resolved)
                    ))
                    subtables.append(.classPairs(index))

                case .cursive(let records):
                    let ruleLower = cursiveRules.count
                    cursiveRules.append(contentsOf: records.map {
                        .init(
                            glyph: $0.glyph,
                            entry: $0.entry.map(resolved),
                            exit: $0.exit.map(resolved)
                        )
                    }.sorted { $0.glyph < $1.glyph })
                    subtables.append(.cursive(ruleLower..<cursiveRules.count))

                case .markToBase(let table):
                    subtables.append(.markToBase(appendMarkBase(
                        table,
                        markRules: &markRules,
                        baseRules: &baseRules,
                        anchors: &anchors,
                        tables: &markBaseTables,
                        resolveAnchor: resolved
                    )))

                case .markToMark(let table):
                    subtables.append(.markToMark(appendMarkBase(
                        table,
                        markRules: &markRules,
                        baseRules: &baseRules,
                        anchors: &anchors,
                        tables: &markBaseTables,
                        resolveAnchor: resolved
                    )))

                case .markToLigature(let table):
                    let markLower = appendMarks(
                        table.marks,
                        to: &markRules,
                        resolveAnchor: resolved
                    )
                    let ligatureLower = ligatureRules.count
                    for ligature in table.ligatures {
                        let componentLower = ligatureComponents.count
                        for component in ligature.components {
                            let anchorLower = anchors.count
                            anchors.append(contentsOf: component.map { $0.map(resolved) })
                            ligatureComponents.append(.init(
                                anchors: anchorLower..<anchors.count
                            ))
                        }
                        ligatureRules.append(.init(
                            glyph: ligature.glyph,
                            components: componentLower..<ligatureComponents.count
                        ))
                    }
                    let tableIndex = markLigatureTables.count
                    markLigatureTables.append(.init(
                        marks: markLower,
                        ligatures: ligatureLower..<ligatureRules.count,
                        classCount: table.classCount
                    ))
                    subtables.append(.markToLigature(tableIndex))

                case .context(let rule):
                    let ruleIndex = contextBuilder.append(rule)
                    subtables.append(.context(ruleIndex..<(ruleIndex + 1)))
                }
            }
            plannedLookups.append(.init(
                sourceIndex: lookup.index,
                flags: lookup.flags,
                subtables: lower..<subtables.count
            ))
        }

        return .init(
            executions: active.map {
                .init(lookupIndex: $0.lookup.index, feature: $0.feature)
            },
            lookups: plannedLookups,
            subtables: subtables,
            singleRules: singleRules,
            pairRules: pairRules,
            classTables: classTables,
            cursiveRules: cursiveRules,
            markRules: markRules,
            baseRules: baseRules,
            anchors: anchors,
            markBaseTables: markBaseTables,
            ligatureRules: ligatureRules,
            ligatureComponents: ligatureComponents,
            markLigatureTables: markLigatureTables,
            context: contextBuilder.build()
        )
    }

    private func appendMarks(
        _ source: [MarkRecord],
        to rules: inout [OpenTypePositioningPlan.MarkRule],
        resolveAnchor: (SFNT.OpenTypeLayout.Anchor) -> SFNT.OpenTypeLayout.Anchor
    ) -> Range<Int> {
        let lower = rules.count
        rules.append(contentsOf: source.map {
            .init(
                glyph: $0.glyph,
                markClass: Int($0.markClass),
                anchor: resolveAnchor($0.anchor)
            )
        }.sorted { $0.glyph < $1.glyph })
        return lower..<rules.count
    }

    private func appendMarkBase(
        _ source: MarkToBaseTable,
        markRules: inout [OpenTypePositioningPlan.MarkRule],
        baseRules: inout [OpenTypePositioningPlan.BaseRule],
        anchors: inout [SFNT.OpenTypeLayout.Anchor?],
        tables: inout [OpenTypePositioningPlan.MarkBaseTable],
        resolveAnchor: (SFNT.OpenTypeLayout.Anchor) -> SFNT.OpenTypeLayout.Anchor
    ) -> Int {
        let marks = appendMarks(
            source.marks,
            to: &markRules,
            resolveAnchor: resolveAnchor
        )
        let baseLower = baseRules.count
        for base in source.bases {
            let anchorLower = anchors.count
            anchors.append(contentsOf: base.anchors.map { $0.map(resolveAnchor) })
            baseRules.append(.init(
                glyph: base.glyph,
                anchors: anchorLower..<anchors.count
            ))
        }
        let index = tables.count
        tables.append(.init(
            marks: marks,
            bases: baseLower..<baseRules.count,
            classCount: source.classCount
        ))
        return index
    }
}

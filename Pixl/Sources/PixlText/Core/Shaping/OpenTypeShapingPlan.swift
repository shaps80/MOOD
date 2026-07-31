struct OpenTypeShapingPlan {
    struct Execution {
        let lookupIndex: Int
        let feature: UInt32
    }

    struct Lookup {
        enum Kind {
            case none
            case single
            case multiple
            case alternate
            case ligature
            case context
            case reverse
        }

        let sourceIndex: Int
        let flags: SFNT.OpenTypeLayout.LookupFlags
        let kind: Kind
        let rules: Range<Int>
    }

    struct SingleRule {
        let input: UInt16
        let output: UInt16
    }

    struct SequenceRule {
        let input: UInt16
        let outputs: Range<Int>
    }

    struct LigatureRule {
        let first: UInt16
        let output: UInt16
        let components: Range<Int>
    }

    struct ReverseRule {
        let inputCoverage: Int
        let backtrackCoverages: Range<Int>
        let lookaheadCoverages: Range<Int>
        let outputs: Range<Int>
    }

    var executions: [Execution]
    let lookups: [Lookup]
    let singleRules: [SingleRule]
    let multipleRules: [SequenceRule]
    let multipleOutputs: [UInt16]
    let alternateRules: [SequenceRule]
    let alternateOutputs: [UInt16]
    let ligatureRules: [LigatureRule]
    let ligatureComponents: [UInt16]
    let context: OpenTypeContextPlan
    let reverseRules: [ReverseRule]
    let reverseCoverageIndices: [Int]
    let reverseOutputs: [UInt16]
}

extension SFNT.GlyphSubstitution {
    func shapingPlan(
        script scriptTag: UInt32,
        language languageTag: UInt32? = nil,
        coordinates: [Float] = []
    ) -> OpenTypeShapingPlan {
        var plan = shapingPlan()
        plan.executions = activeLookups(
            script: scriptTag,
            language: languageTag,
            coordinates: coordinates
        ).map {
            .init(lookupIndex: $0.lookup.index, feature: $0.feature)
        }
        return plan
    }

    func shapingPlan() -> OpenTypeShapingPlan {
        var plannedLookups: [OpenTypeShapingPlan.Lookup] = []
        var singleRules: [OpenTypeShapingPlan.SingleRule] = []
        var multipleRules: [OpenTypeShapingPlan.SequenceRule] = []
        var multipleOutputs: [UInt16] = []
        var alternateRules: [OpenTypeShapingPlan.SequenceRule] = []
        var alternateOutputs: [UInt16] = []
        var ligatureRules: [OpenTypeShapingPlan.LigatureRule] = []
        var ligatureComponents: [UInt16] = []
        var contextBuilder = OpenTypeContextPlanBuilder()
        var reverseRules: [OpenTypeShapingPlan.ReverseRule] = []
        var reverseCoverageIndices: [Int] = []
        var reverseOutputs: [UInt16] = []

        plannedLookups.reserveCapacity(lookups.count)
        for lookup in lookups {
            let kind = kind(of: lookup.substitutions.first)
            let lower: Int
            let upper: Int
            switch kind {
            case .none:
                lower = 0
                upper = 0

            case .single:
                lower = singleRules.count
                let rules = lookup.substitutions.enumerated().compactMap {
                    order, substitution -> (Int, OpenTypeShapingPlan.SingleRule)? in
                    guard case .single(let input, let output) = substitution else { return nil }
                    return (order, .init(input: input, output: output))
                }.sorted {
                    $0.1.input == $1.1.input ? $0.0 < $1.0 : $0.1.input < $1.1.input
                }
                singleRules.append(contentsOf: rules.map(\.1))
                upper = singleRules.count

            case .multiple:
                lower = multipleRules.count
                let rules = lookup.substitutions.enumerated().compactMap {
                    order, substitution -> (Int, UInt16, [UInt16])? in
                    guard case .multiple(let input, let outputs) = substitution else { return nil }
                    return (order, input, outputs)
                }.sorted {
                    $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 < $1.1
                }
                for (_, input, outputs) in rules {
                    let outputLower = multipleOutputs.count
                    multipleOutputs.append(contentsOf: outputs)
                    multipleRules.append(.init(
                        input: input,
                        outputs: outputLower..<multipleOutputs.count
                    ))
                }
                upper = multipleRules.count

            case .alternate:
                lower = alternateRules.count
                let rules = lookup.substitutions.enumerated().compactMap {
                    order, substitution -> (Int, UInt16, [UInt16])? in
                    guard case .alternate(let input, let outputs) = substitution else { return nil }
                    return (order, input, outputs)
                }.sorted {
                    $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 < $1.1
                }
                for (_, input, outputs) in rules {
                    let outputLower = alternateOutputs.count
                    alternateOutputs.append(contentsOf: outputs)
                    alternateRules.append(.init(
                        input: input,
                        outputs: outputLower..<alternateOutputs.count
                    ))
                }
                upper = alternateRules.count

            case .ligature:
                lower = ligatureRules.count
                let rules = lookup.substitutions.enumerated().compactMap {
                    order, substitution -> (Int, [UInt16], UInt16)? in
                    guard case .ligature(let components, let output) = substitution,
                          components.count > 1
                    else { return nil }
                    return (order, components, output)
                }.sorted {
                    $0.1[0] == $1.1[0] ? $0.0 < $1.0 : $0.1[0] < $1.1[0]
                }
                for (_, components, output) in rules {
                    let componentLower = ligatureComponents.count
                    ligatureComponents.append(contentsOf: components)
                    ligatureRules.append(.init(
                        first: components[0],
                        output: output,
                        components: componentLower..<ligatureComponents.count
                    ))
                }
                upper = ligatureRules.count

            case .context:
                lower = contextBuilder.rules.count
                for substitution in lookup.substitutions {
                    guard case .context(let rule) = substitution else { continue }
                    _ = contextBuilder.append(rule)
                }
                upper = contextBuilder.rules.count

            case .reverse:
                lower = reverseRules.count
                for substitution in lookup.substitutions {
                    guard case .reverse(let source) = substitution else { continue }
                    let backtrackLower = reverseCoverageIndices.count
                    reverseCoverageIndices.append(contentsOf: source.backtrack.map {
                        contextBuilder.appendCoverage($0)
                    })
                    let backtrack = backtrackLower..<reverseCoverageIndices.count
                    let lookaheadLower = reverseCoverageIndices.count
                    reverseCoverageIndices.append(contentsOf: source.lookahead.map {
                        contextBuilder.appendCoverage($0)
                    })
                    let outputLower = reverseOutputs.count
                    reverseOutputs.append(contentsOf: source.outputs)
                    reverseRules.append(.init(
                        inputCoverage: contextBuilder.appendCoverage(source.input),
                        backtrackCoverages: backtrack,
                        lookaheadCoverages: lookaheadLower..<reverseCoverageIndices.count,
                        outputs: outputLower..<reverseOutputs.count
                    ))
                }
                upper = reverseRules.count
            }

            plannedLookups.append(.init(
                sourceIndex: lookup.index,
                flags: lookup.flags,
                kind: kind,
                rules: lower..<upper
            ))
        }

        return .init(
            executions: [],
            lookups: plannedLookups,
            singleRules: singleRules,
            multipleRules: multipleRules,
            multipleOutputs: multipleOutputs,
            alternateRules: alternateRules,
            alternateOutputs: alternateOutputs,
            ligatureRules: ligatureRules,
            ligatureComponents: ligatureComponents,
            context: contextBuilder.build(),
            reverseRules: reverseRules,
            reverseCoverageIndices: reverseCoverageIndices,
            reverseOutputs: reverseOutputs
        )
    }

    private func kind(
        of substitution: Substitution?
    ) -> OpenTypeShapingPlan.Lookup.Kind {
        guard let substitution else { return .none }
        return switch substitution {
        case .single: .single
        case .multiple: .multiple
        case .alternate: .alternate
        case .ligature: .ligature
        case .context: .context
        case .reverse: .reverse
        }
    }
}

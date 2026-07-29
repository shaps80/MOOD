struct OpenTypeShapingPlan {
    struct Lookup {
        enum Kind {
            case single
            case ligature
        }

        let sourceIndex: Int
        let feature: UInt32
        let kind: Kind
        let rules: Range<Int>
    }

    struct SingleRule {
        let input: UInt16
        let output: UInt16
    }

    struct LigatureRule {
        let first: UInt16
        let output: UInt16
        let components: Range<Int>
    }

    let lookups: [Lookup]
    let singleRules: [SingleRule]
    let ligatureRules: [LigatureRule]
    let ligatureComponents: [UInt16]
}

extension SFNT.GlyphSubstitution {
    func shapingPlan(
        script scriptTag: UInt32,
        language languageTag: UInt32? = nil
    ) -> OpenTypeShapingPlan {
        let active = activeLookups(script: scriptTag, language: languageTag)
        var plannedLookups: [OpenTypeShapingPlan.Lookup] = []
        var singleRules: [OpenTypeShapingPlan.SingleRule] = []
        var ligatureRules: [OpenTypeShapingPlan.LigatureRule] = []
        var ligatureComponents: [UInt16] = []

        for activeLookup in active {
            let singles: [OpenTypeShapingPlan.SingleRule] = activeLookup.lookup.substitutions.compactMap {
                substitution -> OpenTypeShapingPlan.SingleRule? in
                guard case .single(let input, let output) = substitution else { return nil }
                return OpenTypeShapingPlan.SingleRule(input: input, output: output)
            }.sorted { $0.input < $1.input }
            if !singles.isEmpty {
                let lowerBound = singleRules.count
                singleRules.append(contentsOf: singles)
                plannedLookups.append(.init(
                    sourceIndex: activeLookup.lookup.index,
                    feature: activeLookup.feature,
                    kind: .single,
                    rules: lowerBound..<singleRules.count
                ))
            }

            let ligatures = activeLookup.lookup.substitutions.enumerated().compactMap {
                order, substitution -> (order: Int, components: [UInt16], output: UInt16)? in
                guard case .ligature(let components, let output) = substitution,
                      components.count > 1
                else { return nil }
                return (order, components, output)
            }.sorted {
                $0.components[0] == $1.components[0]
                    ? $0.order < $1.order
                    : $0.components[0] < $1.components[0]
            }
            if !ligatures.isEmpty {
                let lowerBound = ligatureRules.count
                for ligature in ligatures {
                    let componentLowerBound = ligatureComponents.count
                    ligatureComponents.append(contentsOf: ligature.components)
                    ligatureRules.append(.init(
                        first: ligature.components[0],
                        output: ligature.output,
                        components: componentLowerBound..<ligatureComponents.count
                    ))
                }
                plannedLookups.append(.init(
                    sourceIndex: activeLookup.lookup.index,
                    feature: activeLookup.feature,
                    kind: .ligature,
                    rules: lowerBound..<ligatureRules.count
                ))
            }
        }

        return .init(
            lookups: plannedLookups,
            singleRules: singleRules,
            ligatureRules: ligatureRules,
            ligatureComponents: ligatureComponents
        )
    }
}

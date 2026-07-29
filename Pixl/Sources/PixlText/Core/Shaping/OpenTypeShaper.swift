enum OpenTypeShaper {
    static func apply(
        _ substitutions: SFNT.GlyphSubstitution,
        to glyphs: inout [ShapingGlyph],
        script: UnicodeScript,
        language: UInt32? = nil
    ) {
        for active in substitutions.activeLookups(script: script.tag, language: language) {
            apply(active.lookup, feature: active.feature, to: &glyphs)
        }
    }

    private static func apply(
        _ lookup: SFNT.GlyphSubstitution.Lookup,
        feature: UInt32,
        to glyphs: inout [ShapingGlyph]
    ) {
        for substitution in lookup.substitutions {
            switch substitution {
            case .single(let input, let output):
                for index in glyphs.indices where glyphs[index].id.rawValue == input {
                    glyphs[index].id = .init(rawValue: output)
                    glyphs[index].lookupIndex = lookup.index
                    glyphs[index].feature = feature
                }

            case .ligature(let components, let output):
                guard components.count > 1 else { continue }
                var index = 0
                while index + components.count <= glyphs.count {
                    let matches = components.indices.allSatisfy {
                        glyphs[index + $0].id.rawValue == components[$0]
                    }
                    guard matches else {
                        index += 1
                        continue
                    }

                    let lowerBound = glyphs[index].sourceRange.lowerBound
                    let upperBound = glyphs[index + components.count - 1].sourceRange.upperBound
                    let sourceRange = lowerBound..<upperBound
                    glyphs[index] = .init(
                        id: .init(rawValue: output),
                        sourceRange: sourceRange,
                        lookupIndex: lookup.index,
                        feature: feature
                    )
                    glyphs.removeSubrange((index + 1)..<(index + components.count))
                    index += 1
                }
            }
        }
    }
}

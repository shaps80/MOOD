enum LineBreaker {
    static func findOpportunities(
        in text: String,
        styles: Span<ParagraphStyle>,
        workspace: inout LineBreakWorkspace
    ) {
        workspace.removeAll()
        classify(text, into: &workspace.units)
        findAutomaticHyphenation(
            styles: styles,
            units: workspace.units,
            scores: &workspace.hyphenationScores,
            output: &workspace.hyphenationOpportunities
        )

        guard workspace.units.count > 0 else {
            workspace.opportunities.append(.init(sourceOffset: 0, kind: .mandatory))
            return
        }

        var hyphenationIndex = 0
        for boundary in 1...workspace.units.count {
            let offset = boundary == workspace.units.count
                ? text.utf8.count
                : workspace.units[boundary].sourceOffset
            while hyphenationIndex < workspace.hyphenationOpportunities.count,
                  workspace.hyphenationOpportunities[hyphenationIndex].sourceOffset < offset {
                hyphenationIndex += 1
            }
            var kind = breakKind(at: boundary, in: workspace.units)
            if kind == nil,
               hyphenationIndex < workspace.hyphenationOpportunities.count,
               workspace.hyphenationOpportunities[hyphenationIndex].sourceOffset == offset {
                kind = .automaticHyphen
            }
            if var kind {
                if kind == .allowed, workspace.units[boundary - 1].scalar == 0x00AD {
                    kind = .softHyphen
                }
                workspace.opportunities.append(.init(sourceOffset: offset, kind: kind))
            }
        }
    }

    private static func findAutomaticHyphenation(
        styles: Span<ParagraphStyle>,
        units: borrowing LineBreakUnitBuffer,
        scores: inout HyphenationScoreBuffer,
        output: inout LineBreakOpportunityBuffer
    ) {
        guard !styles.isEmpty else { return }
        var paragraphIndex = 0
        var index = 0
        while index < units.count {
            let scalar = units[index].scalar
            if isASCIILetter(scalar) {
                let start = index
                repeat {
                    index += 1
                } while index < units.count && isASCIILetter(units[index].scalar)
                if paragraphIndex < styles.count,
                   styles[paragraphIndex].hyphenation == .automatic {
                    EnglishHyphenator.appendOpportunities(
                        wordRange: start..<index,
                        units: units,
                        scores: &scores,
                        output: &output
                    )
                }
                continue
            }
            if endsParagraph(at: index, units: units) { paragraphIndex += 1 }
            index += 1
        }
    }

    private static func isASCIILetter(_ scalar: UInt32) -> Bool {
        (scalar >= 65 && scalar <= 90) || (scalar >= 97 && scalar <= 122)
    }

    private static func endsParagraph(
        at index: Int,
        units: borrowing LineBreakUnitBuffer
    ) -> Bool {
        switch units[index].raw {
        case .bk, .lf, .nl:
            return true
        case .cr:
            return index + 1 >= units.count || units[index + 1].raw != .lf
        default:
            return false
        }
    }

    private static func classify(_ text: String, into units: inout LineBreakUnitBuffer) {
        var sourceOffset = 0
        for scalar in text.unicodeScalars {
            let attributes = UnicodeLineBreakProperty.attributes(for: scalar)
            var resolved = attributes.lineBreak
            switch resolved {
            case .ai, .sg, .xx:
                resolved = .al
            case .cj:
                resolved = .ns
            case .sa:
                resolved = attributes.isMark ? .cm : .al
            default:
                break
            }

            var isAttached = false
            var isEastAsian = attributes.isEastAsian
            var isInitial = attributes.isInitialPunctuation
            var isFinal = attributes.isFinalPunctuation
            var isExtendedPictographic = attributes.isExtendedPictographic
            if resolved == .cm || resolved == .zwj {
                if units.count > 0 {
                    let base = units[units.count - 1]
                    if ![.bk, .cr, .lf, .nl, .sp, .zw].contains(base.resolved) {
                        resolved = base.resolved
                        isAttached = true
                        isEastAsian = base.isEastAsian
                        isInitial = base.isInitialPunctuation
                        isFinal = base.isFinalPunctuation
                        isExtendedPictographic = base.isExtendedPictographic
                    } else {
                        resolved = .al
                    }
                } else {
                    resolved = .al
                }
            }

            units.append(.init(
                scalar: scalar.value,
                sourceOffset: sourceOffset,
                raw: attributes.lineBreak,
                resolved: resolved,
                isAttached: isAttached,
                isEastAsian: isEastAsian,
                isInitialPunctuation: isInitial,
                isFinalPunctuation: isFinal,
                isExtendedPictographic: isExtendedPictographic
            ))
            sourceOffset += scalar.utf8.count
        }
    }

    private static func breakKind(
        at boundary: Int,
        in units: borrowing LineBreakUnitBuffer
    ) -> LineBreakKind? {
        if boundary == units.count { return .mandatory } // LB3
        let leftIndex = boundary - 1
        let left = units[leftIndex]
        let right = units[boundary]
        let l = left.resolved
        let r = right.resolved

        if l == .bk { return .mandatory } // LB4
        if l == .cr { return r == .lf ? nil : .mandatory } // LB5
        if l == .lf || l == .nl { return .mandatory } // LB5
        if isHardBreak(r) { return nil } // LB6
        if r == .sp || r == .zw { return nil } // LB7
        if previousNonSpace(before: boundary, in: units).map({ units[$0].raw == .zw }) == true {
            return .allowed // LB8
        }
        if left.raw == .zwj { return nil } // LB8a
        if right.isAttached { return nil } // LB9
        if l == .wj || r == .wj { return nil } // LB11
        if l == .gl { return nil } // LB12
        if r == .gl && ![.sp, .ba, .hy].contains(l) { return nil } // LB12a

        // LB15c precedes the general IS prohibition introduced by LB15d.
        if l == .sp, r == .is, nextSignificant(after: boundary, in: units).map({ units[$0].resolved == .nu }) == true {
            return .allowed
        }
        if [.cl, .cp, .ex, .is, .sy].contains(r) { return nil } // LB13, LB15d
        if let index = previousNonSpace(before: boundary, in: units), units[index].resolved == .op {
            return nil // LB14
        }
        if blocksAfterInitialQuote(at: boundary, in: units) { return nil } // LB15a
        if blocksBeforeFinalQuote(at: boundary, in: units) { return nil } // LB15b
        if let index = previousNonSpace(before: boundary, in: units),
           [.cl, .cp].contains(units[index].resolved), r == .ns {
            return nil // LB16
        }
        if let index = previousNonSpace(before: boundary, in: units),
           units[index].resolved == .b2, r == .b2 {
            return nil // LB17
        }
        if l == .sp { return .allowed } // LB18
        if blocksUnresolvedQuote(at: boundary, in: units) { return nil } // LB19, LB19a
        if l == .cb || r == .cb { return .allowed } // LB20
        if isWordInitialHyphen(leftIndex, before: r, in: units) { return nil } // LB20a
        if [.ba, .hy, .ns].contains(r) || l == .bb { return nil } // LB21
        if leftIndex > 0, [.hy, .ba].contains(l), units[leftIndex - 1].resolved == .hl,
           r != .hl, (l == .hy || !left.isEastAsian) {
            return nil // LB21a
        }
        if l == .sy && r == .hl { return nil } // LB21b
        if r == .in { return nil } // LB22
        if ([.al, .hl].contains(l) && r == .nu) || (l == .nu && [.al, .hl].contains(r)) {
            return nil // LB23
        }
        if (l == .pr && [.id, .eb, .em].contains(r)) || ([.id, .eb, .em].contains(l) && r == .po) {
            return nil // LB23a
        }
        if ([.pr, .po].contains(l) && [.al, .hl].contains(r))
            || ([.al, .hl].contains(l) && [.pr, .po].contains(r)) {
            return nil // LB24
        }
        if blocksNumericExpression(at: boundary, in: units) { return nil } // LB25
        if l == .jl && [.jl, .jv, .h2, .h3].contains(r) { return nil }
        if [.jv, .h2].contains(l) && [.jv, .jt].contains(r) { return nil }
        if [.jt, .h3].contains(l) && r == .jt { return nil } // LB26
        if ([.jl, .jv, .jt, .h2, .h3].contains(l) && r == .po)
            || (l == .pr && [.jl, .jv, .jt, .h2, .h3].contains(r)) {
            return nil // LB27
        }
        if [.al, .hl].contains(l) && [.al, .hl].contains(r) { return nil } // LB28
        if blocksAksara(at: boundary, in: units) { return nil } // LB28a
        if l == .is && [.al, .hl].contains(r) { return nil } // LB29
        if [.al, .hl, .nu].contains(l) && r == .op && !right.isEastAsian { return nil }
        if l == .cp && !left.isEastAsian && [.al, .hl, .nu].contains(r) { return nil } // LB30
        if l == .ri && r == .ri && regionalIndicatorCount(before: boundary, in: units) % 2 == 1 {
            return nil // LB30a
        }
        if (l == .eb || left.isExtendedPictographic) && r == .em { return nil } // LB30b
        return .allowed // LB31
    }

    private static func isHardBreak(_ value: UnicodeLineBreakProperty) -> Bool {
        [.bk, .cr, .lf, .nl].contains(value)
    }

    private static func previousNonSpace(
        before boundary: Int,
        in units: borrowing LineBreakUnitBuffer
    ) -> Int? {
        var index = boundary - 1
        while index >= 0, units[index].resolved == .sp { index -= 1 }
        return index >= 0 ? index : nil
    }

    private static func nextSignificant(
        after index: Int,
        in units: borrowing LineBreakUnitBuffer
    ) -> Int? {
        var next = index + 1
        while next < units.count, units[next].isAttached { next += 1 }
        return next < units.count ? next : nil
    }

    private static func blocksAfterInitialQuote(
        at boundary: Int,
        in units: borrowing LineBreakUnitBuffer
    ) -> Bool {
        guard let quote = previousNonSpace(before: boundary, in: units),
              units[quote].resolved == .qu, units[quote].isInitialPunctuation
        else { return false }
        guard quote > 0 else { return true }
        return [.bk, .cr, .lf, .nl, .op, .qu, .gl, .sp, .zw].contains(units[quote - 1].resolved)
    }

    private static func blocksBeforeFinalQuote(
        at boundary: Int,
        in units: borrowing LineBreakUnitBuffer
    ) -> Bool {
        let quote = units[boundary]
        guard quote.resolved == .qu, quote.isFinalPunctuation else { return false }
        guard let next = nextSignificant(after: boundary, in: units) else { return true }
        return [.sp, .gl, .wj, .cl, .qu, .cp, .ex, .is, .sy, .bk, .cr, .lf, .nl, .zw]
            .contains(units[next].resolved)
    }

    private static func blocksUnresolvedQuote(
        at boundary: Int,
        in units: borrowing LineBreakUnitBuffer
    ) -> Bool {
        let left = units[boundary - 1]
        let right = units[boundary]
        if right.resolved == .qu {
            if !right.isInitialPunctuation { return true }
            if !left.isEastAsian { return true }
            if let next = nextSignificant(after: boundary, in: units), !units[next].isEastAsian { return true }
            if nextSignificant(after: boundary, in: units) == nil { return true }
        }
        if left.resolved == .qu {
            if !left.isFinalPunctuation { return true }
            if !right.isEastAsian { return true }
            if boundary < 2 || !units[boundary - 2].isEastAsian { return true }
        }
        return false
    }

    private static func isWordInitialHyphen(
        _ hyphen: Int,
        before right: UnicodeLineBreakProperty,
        in units: borrowing LineBreakUnitBuffer
    ) -> Bool {
        guard right == .al,
              units[hyphen].resolved == .hy || units[hyphen].scalar == 0x2010
        else { return false }
        guard hyphen > 0 else { return true }
        return [.bk, .cr, .lf, .nl, .sp, .zw, .cb, .gl].contains(units[hyphen - 1].resolved)
    }

    private static func blocksNumericExpression(
        at boundary: Int,
        in units: borrowing LineBreakUnitBuffer
    ) -> Bool {
        let l = units[boundary - 1].resolved
        let r = units[boundary].resolved
        if [.hy, .is, .sy].contains(l) && r == .nu { return true }
        if [.pr, .po].contains(l) {
            if r == .nu { return true }
            if r == .op,
               let next = nextSignificant(after: boundary, in: units),
               units[next].resolved == .nu
                || (units[next].resolved == .is
                    && nextSignificant(after: next, in: units).map { units[$0].resolved == .nu } == true) {
                return true
            }
        }
        if [.po, .pr, .nu].contains(r) {
            var index = boundary - 1
            if [.cl, .cp].contains(units[index].resolved) { index -= 1 }
            while index >= 0, [.sy, .is].contains(units[index].resolved) { index -= 1 }
            if index >= 0, units[index].resolved == .nu { return true }
        }
        return false
    }

    private static func blocksAksara(
        at boundary: Int,
        in units: borrowing LineBreakUnitBuffer
    ) -> Bool {
        let left = units[boundary - 1]
        let right = units[boundary]
        let leftBase = [.ak, .as].contains(left.resolved) || left.scalar == 0x25CC
        let rightBase = [.ak, .as].contains(right.resolved) || right.scalar == 0x25CC
        if left.resolved == .ap && rightBase { return true }
        if leftBase && [.vf, .vi].contains(right.resolved) { return true }
        if left.resolved == .vi, boundary >= 2 {
            let prior = units[boundary - 2]
            if ([.ak, .as].contains(prior.resolved) || prior.scalar == 0x25CC)
                && ([.ak].contains(right.resolved) || right.scalar == 0x25CC) { return true }
        }
        if leftBase, rightBase,
           let next = nextSignificant(after: boundary, in: units), units[next].resolved == .vf {
            return true
        }
        return false
    }

    private static func regionalIndicatorCount(
        before boundary: Int,
        in units: borrowing LineBreakUnitBuffer
    ) -> Int {
        var count = 0
        var index = boundary - 1
        while index >= 0, units[index].resolved == .ri {
            count += 1
            index -= 1
        }
        return count
    }
}

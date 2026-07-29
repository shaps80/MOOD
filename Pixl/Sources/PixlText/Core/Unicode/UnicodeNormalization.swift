enum UnicodeNormalization {
    static func normalizeNFC<Scalars: Collection>(
        _ input: Scalars,
        using buffer: inout UnicodeNormalizationBuffer
    ) where Scalars.Element == Unicode.Scalar {
        buffer.removeAll()

        for scalar in input {
            appendCanonicalDecomposition(of: scalar.value, to: &buffer.decomposed)
        }

        compose(buffer.decomposed, into: &buffer.normalized)
    }

    private static func appendCanonicalDecomposition(
        of scalar: UInt32,
        to output: inout [Unicode.Scalar]
    ) {
        if let hangul = hangulDecomposition(of: scalar) {
            for component in hangul {
                appendOrdered(component, to: &output)
            }
            return
        }

        if let entry = decompositionEntry(for: scalar) {
            let start = Int(entry.offset)
            let end = start + Int(entry.count)
            for component in decompositionScalars[start..<end] {
                appendCanonicalDecomposition(of: component, to: &output)
            }
            return
        }

        appendOrdered(scalar, to: &output)
    }

    private static func appendOrdered(
        _ value: UInt32,
        to output: inout [Unicode.Scalar]
    ) {
        let scalar = Unicode.Scalar(value)!
        let currentClass = combiningClass(of: value)
        output.append(scalar)

        guard currentClass != 0 else { return }

        var index = output.index(before: output.endIndex)
        while index > output.startIndex {
            let previous = output.index(before: index)
            let previousClass = combiningClass(of: output[previous].value)
            guard previousClass > currentClass else { break }
            output.swapAt(previous, index)
            index = previous
        }
    }

    private static func compose(
        _ decomposed: [Unicode.Scalar],
        into output: inout [Unicode.Scalar]
    ) {
        guard let first = decomposed.first else { return }

        output.append(first)
        var starterIndex: Int? = combiningClass(of: first.value) == 0 ? 0 : nil
        var lastClass: UInt8 = 0

        for scalar in decomposed.dropFirst() {
            let currentClass = combiningClass(of: scalar.value)

            if let starterIndex,
               lastClass < currentClass || lastClass == 0,
               let result = composition(
                   first: output[starterIndex].value,
                   second: scalar.value
               ) {
                output[starterIndex] = Unicode.Scalar(result)!
                continue
            }

            output.append(scalar)
            if currentClass == 0 {
                starterIndex = output.index(before: output.endIndex)
            }
            lastClass = currentClass
        }
    }

    private static func decompositionEntry(for scalar: UInt32) -> DecompositionEntry? {
        binarySearch(decompositionEntries, scalar: scalar, keyPath: \.scalar)
    }

    private static func combiningClass(of scalar: UInt32) -> UInt8 {
        binarySearch(combiningClassEntries, scalar: scalar, keyPath: \.scalar)?.value ?? 0
    }

    private static func composition(first: UInt32, second: UInt32) -> UInt32? {
        if let hangul = hangulComposition(first: first, second: second) {
            return hangul
        }

        var lower = 0
        var upper = compositionEntries.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            let entry = compositionEntries[middle]
            if entry.first < first || entry.first == first && entry.second < second {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        guard lower < compositionEntries.count else { return nil }
        let entry = compositionEntries[lower]
        return entry.first == first && entry.second == second ? entry.result : nil
    }

    private static func binarySearch<Entry>(
        _ entries: [Entry],
        scalar: UInt32,
        keyPath: KeyPath<Entry, UInt32>
    ) -> Entry? {
        var lower = 0
        var upper = entries.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if entries[middle][keyPath: keyPath] < scalar {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        guard lower < entries.count, entries[lower][keyPath: keyPath] == scalar else {
            return nil
        }
        return entries[lower]
    }

    private static func hangulDecomposition(of scalar: UInt32) -> [UInt32]? {
        let sBase: UInt32 = 0xAC00
        let lBase: UInt32 = 0x1100
        let vBase: UInt32 = 0x1161
        let tBase: UInt32 = 0x11A7
        let lCount: UInt32 = 19
        let vCount: UInt32 = 21
        let tCount: UInt32 = 28
        let nCount = vCount * tCount
        let sCount = lCount * nCount

        guard scalar >= sBase, scalar < sBase + sCount else { return nil }
        let index = scalar - sBase
        let leading = lBase + index / nCount
        let vowel = vBase + index % nCount / tCount
        let trailing = index % tCount
        return trailing == 0
            ? [leading, vowel]
            : [leading, vowel, tBase + trailing]
    }

    private static func hangulComposition(first: UInt32, second: UInt32) -> UInt32? {
        let sBase: UInt32 = 0xAC00
        let lBase: UInt32 = 0x1100
        let vBase: UInt32 = 0x1161
        let tBase: UInt32 = 0x11A7
        let lCount: UInt32 = 19
        let vCount: UInt32 = 21
        let tCount: UInt32 = 28
        let nCount = vCount * tCount
        let sCount = lCount * nCount

        if first >= lBase, first < lBase + lCount,
           second >= vBase, second < vBase + vCount {
            return sBase + (first - lBase) * nCount + (second - vBase) * tCount
        }

        if first >= sBase, first < sBase + sCount,
           (first - sBase) % tCount == 0,
           second > tBase, second < tBase + tCount {
            return first + second - tBase
        }

        return nil
    }
}

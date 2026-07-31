enum EnglishHyphenator {
    static func appendOpportunities(
        wordRange: Range<Int>,
        units: borrowing LineBreakUnitBuffer,
        scores: inout HyphenationScoreBuffer,
        output: inout LineBreakOpportunityBuffer
    ) {
        let letterCount = wordRange.count
        guard letterCount >= 5 else { return }

        if let exceptionMask = exceptionMask(wordRange: wordRange, units: units) {
            for boundary in 2...(letterCount - 3) where exceptionMask & (1 << boundary) != 0 {
                output.append(.init(
                    sourceOffset: units[wordRange.lowerBound + boundary].sourceOffset,
                    kind: .automaticHyphen
                ))
            }
            return
        }

        let paddedCount = letterCount + 2
        scores.prepare(count: paddedCount + 1)
        for start in 0..<paddedCount {
            var node = 0
            var position = start
            while position < paddedCount,
                  let child = child(of: node, scalar: paddedScalar(
                    at: position,
                    wordRange: wordRange,
                    units: units
                  )) {
                node = child
                let weightCount = Int(nodeWeightCount[node])
                if weightCount > 0 {
                    let offset = Int(nodeWeightOffset[node])
                    for weightIndex in 0..<weightCount {
                        let scoreIndex = start + weightIndex
                        scores[scoreIndex] = max(scores[scoreIndex], weights[offset + weightIndex])
                    }
                }
                position += 1
            }
        }

        for boundary in 2...(letterCount - 3) where scores[boundary + 1] & 1 == 1 {
            output.append(.init(
                sourceOffset: units[wordRange.lowerBound + boundary].sourceOffset,
                kind: .automaticHyphen
            ))
        }
    }

    private static func exceptionMask(
        wordRange: Range<Int>,
        units: borrowing LineBreakUnitBuffer
    ) -> UInt32? {
        var node = 0
        for index in wordRange {
            guard let child = child(of: node, scalar: lowercaseASCII(units[index].scalar)) else {
                return nil
            }
            node = child
        }
        return nodeHasException[node] == 0 ? nil : nodeExceptionMask[node]
    }

    private static func child(of node: Int, scalar: UInt8) -> Int? {
        let start = Int(nodeFirstEdge[node])
        let end = start + Int(nodeEdgeCount[node])
        for edge in start..<end {
            let candidate = edgeScalars[edge]
            if candidate == scalar { return Int(edgeTargets[edge]) }
            if candidate > scalar { return nil }
        }
        return nil
    }

    private static func paddedScalar(
        at index: Int,
        wordRange: Range<Int>,
        units: borrowing LineBreakUnitBuffer
    ) -> UInt8 {
        if index == 0 || index == wordRange.count + 1 { return 46 }
        return lowercaseASCII(units[wordRange.lowerBound + index - 1].scalar)
    }

    private static func lowercaseASCII(_ scalar: UInt32) -> UInt8 {
        let value = UInt8(truncatingIfNeeded: scalar)
        return value >= 65 && value <= 90 ? value + 32 : value
    }
}

struct UnicodeNormalizationBuffer {
    var decomposed: [Unicode.Scalar] = []
    var normalized: [Unicode.Scalar] = []

    mutating func removeAll(keepingCapacity: Bool = true) {
        decomposed.removeAll(keepingCapacity: keepingCapacity)
        normalized.removeAll(keepingCapacity: keepingCapacity)
    }
}

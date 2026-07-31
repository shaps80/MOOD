struct LineBreakWorkspace: ~Copyable {
    var opportunities: LineBreakOpportunityBuffer
    var units: LineBreakUnitBuffer
    var hyphenationOpportunities: LineBreakOpportunityBuffer
    var hyphenationScores: HyphenationScoreBuffer

    init(minimumScalarCapacity: Int = 0, minimumOpportunityCapacity: Int = 0) {
        units = .init(minimumCapacity: minimumScalarCapacity)
        opportunities = .init(minimumCapacity: minimumOpportunityCapacity)
        hyphenationOpportunities = .init(minimumCapacity: minimumOpportunityCapacity)
        hyphenationScores = .init()
    }

    mutating func removeAll(keepingCapacity: Bool = true) {
        units.removeAll(keepingCapacity: keepingCapacity)
        opportunities.removeAll(keepingCapacity: keepingCapacity)
        hyphenationOpportunities.removeAll(keepingCapacity: keepingCapacity)
        hyphenationScores.removeAll(keepingCapacity: keepingCapacity)
    }
}

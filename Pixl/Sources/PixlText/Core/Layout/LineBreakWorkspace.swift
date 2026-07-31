struct LineBreakWorkspace: ~Copyable {
    var opportunities: LineBreakOpportunityBuffer
    var units: LineBreakUnitBuffer

    init(minimumScalarCapacity: Int = 0, minimumOpportunityCapacity: Int = 0) {
        units = .init(minimumCapacity: minimumScalarCapacity)
        opportunities = .init(minimumCapacity: minimumOpportunityCapacity)
    }

    mutating func removeAll(keepingCapacity: Bool = true) {
        units.removeAll(keepingCapacity: keepingCapacity)
        opportunities.removeAll(keepingCapacity: keepingCapacity)
    }
}

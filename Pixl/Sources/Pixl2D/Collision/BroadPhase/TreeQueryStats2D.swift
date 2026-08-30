/// Work performed by one dynamic-tree query.
package struct TreeQueryStats2D: Equatable, Sendable {
    var nodeVisits: Int
    var leafVisits: Int

    init(nodeVisits: Int = 0, leafVisits: Int = 0) {
        self.nodeVisits = nodeVisits
        self.leafVisits = leafVisits
    }
}

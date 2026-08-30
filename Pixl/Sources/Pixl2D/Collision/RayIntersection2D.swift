/// The nearest broad-phase proxy and its ray intersection.
public struct RayIntersection2D: Equatable, Sendable {
    public let proxy: ProxyID
    public let hit: RayHit2D

    public init(proxy: ProxyID, hit: RayHit2D) {
        self.proxy = proxy
        self.hit = hit
    }
}

import Swift

public extension Rect {
    func padding(_ edges: Edge.Set = .all, _ amount: Float) -> Rect {
        var origin = origin
        var size = size

        if edges.contains(.leading) {
            origin.x += amount
            size.x -= amount
        }
        if edges.contains(.trailing) { size.x -= amount }
        if edges.contains(.top) {
            origin.y += amount
            size.y -= amount
        }
        if edges.contains(.bottom) { size.y -= amount }

        return Rect(origin: origin, size: size)
    }
}

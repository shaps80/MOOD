enum ColliderGeometry2D {
    case rect(size: Size)
    case polygon(PolygonColliderGeometry2D)

    func contact(
        bounds: Rect,
        with other: ColliderGeometry2D,
        bounds otherBounds: Rect
    ) -> Contact2D? {
        switch (self, other) {
        case (.rect, .rect):
            return bounds.contact(with: otherBounds)
        case (.rect, .polygon(let polygon)):
            return polygon.contact(from: bounds)
        case (.polygon(let polygon), .rect):
            guard let contact = polygon.contact(from: otherBounds) else {
                return nil
            }
            return .init(normal: -contact.normal, depth: contact.depth)
        case (.polygon(let source), .polygon(let target)):
            return target.contact(from: source)
        }
    }

    func intersection(bounds: Rect, with ray: Ray2D) -> RayHit2D? {
        switch self {
        case .rect:
            return bounds.intersection(with: ray)
        case .polygon(let polygon):
            return polygon.intersection(with: ray)
        }
    }
}

enum ColliderGeometry2D {
    case rect(size: Size)
    case polygon(PolygonColliderGeometry2D)
    case circle(CircleColliderGeometry2D)
    case capsule(CapsuleColliderGeometry2D)

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
        case (.rect, .circle(let circle)):
            return circle.contact(from: bounds)
        case (.circle(let circle), .rect):
            guard let contact = circle.contact(from: otherBounds) else {
                return nil
            }
            return contact.reversed
        case (.polygon(let polygon), .circle(let circle)):
            guard let contact = polygon.contact(from: circle) else {
                return nil
            }
            return contact.reversed
        case (.circle(let circle), .polygon(let polygon)):
            return polygon.contact(from: circle)
        case (.circle(let source), .circle(let target)):
            return target.contact(from: source)
        case (.rect, .capsule(let capsule)):
            return capsule.contact(from: bounds)
        case (.capsule(let capsule), .rect):
            guard let contact = capsule.contact(from: otherBounds) else {
                return nil
            }
            return contact.reversed
        case (.polygon(let polygon), .capsule(let capsule)):
            guard let contact = polygon.contact(from: capsule) else {
                return nil
            }
            return contact.reversed
        case (.capsule(let capsule), .polygon(let polygon)):
            return polygon.contact(from: capsule)
        case (.circle(let circle), .capsule(let capsule)):
            return capsule.contact(from: circle)
        case (.capsule(let capsule), .circle(let circle)):
            guard let contact = capsule.contact(from: circle) else {
                return nil
            }
            return contact.reversed
        case (.capsule(let source), .capsule(let target)):
            return target.contact(from: source)
        }
    }

    func intersection(bounds: Rect, with ray: Ray2D) -> RayHit2D? {
        switch self {
        case .rect:
            return bounds.intersection(with: ray)
        case .polygon(let polygon):
            return polygon.intersection(with: ray)
        case .circle(let circle):
            return circle.intersection(with: ray)
        case .capsule(let capsule):
            return capsule.intersection(with: ray)
        }
    }
}

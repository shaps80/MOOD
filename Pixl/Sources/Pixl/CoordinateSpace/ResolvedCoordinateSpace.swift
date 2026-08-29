import Pixl2D

/// A presentation coordinate space prepared for repeated input conversion.
public struct ResolvedCoordinateSpace: Sendable {
    private let rawToResolved: Transform2D?

    package init(
        pixelSize: Vec2,
        inverseDisplayScale: Float,
        coordinateSpace: CoordinateSpace
    ) {
        switch coordinateSpace {
        case .screen:
            rawToResolved = .init(
                x: .init(inverseDisplayScale, 0, 0),
                y: .init(0, -inverseDisplayScale, 0),
                translation: .init(
                    0,
                    pixelSize.y * inverseDisplayScale,
                    1
                )
            )
        case .world(let camera):
            guard let inverse = camera.projection(in: pixelSize).inverted else {
                rawToResolved = nil
                return
            }
            let scale = 2 / pixelSize
            let rawToClip = Transform2D(
                x: .init(scale.x, 0, 0),
                y: .init(0, scale.y, 0),
                translation: .init(-1, -1, 1)
            )
            rawToResolved = Self.concatenating(rawToClip, then: inverse)
        }
    }

    package init() {
        rawToResolved = nil
    }

    private init(rawToResolved: Transform2D?) {
        self.rawToResolved = rawToResolved
    }

    /// Whether this space can currently resolve coordinates.
    public var isValid: Bool {
        rawToResolved != nil
    }

    /// Returns this coordinate space resolved relative to a local transform.
    ///
    /// The transform is inverted once when creating the returned value. Point
    /// and vector resolution then uses only the resulting composed transform.
    public func coordinates(relativeTo transform: Transform2D) -> Self {
        guard let rawToResolved, let inverse = transform.inverted else {
            return .init(rawToResolved: nil)
        }
        return .init(
            rawToResolved: Self.concatenating(rawToResolved, then: inverse)
        )
    }

    package func location(forRawLocation rawLocation: Vec2) -> Vec2 {
        guard let rawToResolved else { return .invalid }
        return rawToResolved.transformed(point: rawLocation)
    }

    package func translation(forRawTranslation rawTranslation: Vec2) -> Vec2 {
        guard let rawToResolved else { return .zero }
        return rawToResolved.transformed(vector: rawTranslation)
    }

    private static func concatenating(
        _ first: Transform2D,
        then second: Transform2D
    ) -> Transform2D {
        .init(
            x: second.x * first.x.x + second.y * first.x.y,
            y: second.x * first.y.x + second.y * first.y.y,
            translation: second.x * first.translation.x
                + second.y * first.translation.y
                + second.translation
        )
    }
}

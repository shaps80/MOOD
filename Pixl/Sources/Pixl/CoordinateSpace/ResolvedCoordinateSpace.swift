import Pixl2D

/// A presentation coordinate space prepared for repeated input conversion.
public struct ResolvedCoordinateSpace: Sendable {
    private enum Storage: Sendable {
        case invalid
        case screen(pixelHeight: Float, inverseDisplayScale: Float)
        case world(rawToClipScale: Vec2, inverseProjection: Transform2D)
    }

    private let storage: Storage

    package init(
        pixelSize: Vec2,
        inverseDisplayScale: Float,
        coordinateSpace: CoordinateSpace
    ) {
        switch coordinateSpace {
        case .screen:
            storage = .screen(
                pixelHeight: pixelSize.y,
                inverseDisplayScale: inverseDisplayScale
            )
        case .world(let camera):
            guard let inverse = camera.projection(in: pixelSize).inverted else {
                storage = .invalid
                return
            }
            storage = .world(
                rawToClipScale: 2 / pixelSize,
                inverseProjection: inverse
            )
        }
    }

    package init() {
        storage = .invalid
    }

    /// Whether this space can currently resolve coordinates.
    public var isValid: Bool {
        if case .invalid = storage { false } else { true }
    }

    package func location(forRawLocation rawLocation: Vec2) -> Vec2 {
        switch storage {
        case .invalid:
            return .invalid
        case .screen(let pixelHeight, let inverseDisplayScale):
            return .init(
                rawLocation.x * inverseDisplayScale,
                (pixelHeight - rawLocation.y) * inverseDisplayScale
            )
        case .world(let rawToClipScale, let inverseProjection):
            let clip = rawLocation * rawToClipScale - 1
            return inverseProjection.transformed(point: clip)
        }
    }

    package func translation(forRawTranslation rawTranslation: Vec2) -> Vec2 {
        switch storage {
        case .invalid:
            return .zero
        case .screen(_, let inverseDisplayScale):
            return .init(
                rawTranslation.x * inverseDisplayScale,
                -rawTranslation.y * inverseDisplayScale
            )
        case .world(let rawToClipScale, let inverseProjection):
            let clip = rawTranslation * rawToClipScale
            return inverseProjection.transformed(vector: clip)
        }
    }
}

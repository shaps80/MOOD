import Pixl2D
import PixlPlatform

/// Frame-local coordinate conversion derived from presentation dimensions.
package struct CoordinateConverter {
    private let pixelSize: Vec2
    private let logicalSize: Vec2
    private let inverseDisplayScale: Float

    package init?(presentationSize: TextureSize, displayScale: Float) {
        guard presentationSize.width > 0,
              presentationSize.height > 0,
              displayScale.isFinite,
              displayScale > 0
        else { return nil }

        pixelSize = .init(
            Float(presentationSize.width),
            Float(presentationSize.height)
        )
        inverseDisplayScale = 1 / displayScale
        logicalSize = pixelSize * inverseDisplayScale
    }

    package func location(
        _ rawLocation: Vec2,
        in coordinateSpace: CoordinateSpace
    ) -> Vec2 {
        switch coordinateSpace {
        case .screen:
            return .init(
                rawLocation.x * inverseDisplayScale,
                (pixelSize.y - rawLocation.y) * inverseDisplayScale
            )

        case .world(let camera):
            let clip = Vec2(
                rawLocation.x / pixelSize.x * 2 - 1,
                rawLocation.y / pixelSize.y * 2 - 1
            )
            guard let inverse = camera.projection(in: pixelSize).inverted else {
                return .invalid
            }
            return inverse.transformed(point: clip)
        }
    }

    package func translation(
        _ rawTranslation: Vec2,
        in coordinateSpace: CoordinateSpace
    ) -> Vec2 {
        switch coordinateSpace {
        case .screen:
            return .init(
                rawTranslation.x * inverseDisplayScale,
                -rawTranslation.y * inverseDisplayScale
            )

        case .world(let camera):
            let clip = Vec2(
                rawTranslation.x / pixelSize.x * 2,
                rawTranslation.y / pixelSize.y * 2
            )
            guard let inverse = camera.projection(in: pixelSize).inverted else {
                return .zero
            }
            return inverse.transformed(vector: clip)
        }
    }

    package func convert(
        _ point: Vec2,
        from source: CoordinateSpace,
        to destination: CoordinateSpace
    ) -> Vec2 {
        guard point.isValid else { return .invalid }

        switch (source, destination) {
        case (.screen, .screen), (.world, .world):
            return point

        case (.screen, .world(let camera)):
            guard let inverse = camera.projection(in: pixelSize).inverted else {
                return .invalid
            }
            return inverse.transformed(point: clipPoint(from: point))

        case (.world(let camera), .screen):
            let clip = camera.projection(in: pixelSize)
                .transformed(point: point)
            guard clip.isValid else { return .invalid }
            return screenPoint(from: clip)
        }
    }

    package func convert(
        _ bounds: Rect,
        from source: CoordinateSpace,
        to destination: CoordinateSpace
    ) -> Rect {
        guard bounds.isValid else { return .invalid }

        switch (source, destination) {
        case (.screen, .screen), (.world, .world):
            return bounds

        case (.screen, .world(let camera)):
            guard let inverse = camera.projection(in: pixelSize).inverted else {
                return .invalid
            }
            return convertedBounds(
                inverse.transformed(point: clipPoint(from: bounds.origin)),
                inverse.transformed(point: clipPoint(from: .init(bounds.maxX, bounds.minY))),
                inverse.transformed(point: clipPoint(from: .init(bounds.minX, bounds.maxY))),
                inverse.transformed(point: clipPoint(from: .init(bounds.maxX, bounds.maxY)))
            )

        case (.world(let camera), .screen):
            let projection = camera.projection(in: pixelSize)
            return convertedBounds(
                screenPoint(from: projection.transformed(point: bounds.origin)),
                screenPoint(from: projection.transformed(point: .init(bounds.maxX, bounds.minY))),
                screenPoint(from: projection.transformed(point: .init(bounds.minX, bounds.maxY))),
                screenPoint(from: projection.transformed(point: .init(bounds.maxX, bounds.maxY)))
            )
        }
    }

    private func clipPoint(from screenPoint: Vec2) -> Vec2 {
        .init(
            screenPoint.x / logicalSize.x * 2 - 1,
            1 - screenPoint.y / logicalSize.y * 2
        )
    }

    private func screenPoint(from clipPoint: Vec2) -> Vec2 {
        .init(
            (clipPoint.x + 1) * logicalSize.x / 2,
            (1 - clipPoint.y) * logicalSize.y / 2
        )
    }

    private func convertedBounds(
        _ first: Vec2,
        _ second: Vec2,
        _ third: Vec2,
        _ fourth: Vec2
    ) -> Rect {
        guard first.isValid, second.isValid, third.isValid, fourth.isValid else {
            return .invalid
        }
        let minimum = Vec2(
            min(min(first.x, second.x), min(third.x, fourth.x)),
            min(min(first.y, second.y), min(third.y, fourth.y))
        )
        let maximum = Vec2(
            max(max(first.x, second.x), max(third.x, fourth.x)),
            max(max(first.y, second.y), max(third.y, fourth.y))
        )
        return .init(origin: minimum, size: maximum - minimum)
    }
}

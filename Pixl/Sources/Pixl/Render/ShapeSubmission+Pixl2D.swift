import Pixl2D
import PixlFoundation
import PixlGraphics
import PixlPlatform

extension ShapeSubmission {
    init(shape: Shape, transform sourceTransform: Transform2D, gradientSlot: UInt32 = .max) {
        let kind: ShapeKind
        let size: SIMD2<Float>
        let parameters: SIMD4<Float>
        var extendedParameters = SIMD4<Float>.zero
        var localOffset = Vec2.zero
        switch shape.geometry {
        case .circle(let circle):
            let diameter = Float((circle.radius ?? 0.5) * 2)
            size = .init(repeating: diameter)
            parameters = .init(diameter * 0.5, diameter * 0.5, 0, 0)
            kind = .circle
        case .rectangle(let rectangle):
            let localSize = rectangle.size ?? .one
            size = .init(Float(localSize.x), Float(localSize.y))
            parameters = .init(
                size.x * 0.5,
                size.y * 0.5,
                0,
                0
            )
            kind = .rectangle
        case .unevenRoundedRectangle(let rectangle):
            let localSize = rectangle.size ?? .one
            size = .init(Float(localSize.x), Float(localSize.y))
            let radii = rectangle.cornerRadii.normalized(to: size)
            parameters = .init(
                size.x * 0.5,
                size.y * 0.5,
                radii.topLeading,
                radii.topTrailing
            )
            extendedParameters = .init(
                radii.bottomLeading,
                radii.bottomTrailing,
                0,
                0
            )
            kind = .unevenRoundedRectangle
        case .segment(let segment):
            let minimum = SIMD2<Float>(Float(min(segment.start.x, segment.end.x)), Float(min(segment.start.y, segment.end.y)))
            let maximum = SIMD2<Float>(Float(max(segment.start.x, segment.end.x)), Float(max(segment.start.y, segment.end.y)))
            size = .init(
                max(maximum.x - minimum.x, 0.0001),
                max(maximum.y - minimum.y, 0.0001)
            )
            localOffset = (segment.start + segment.end) * 0.5
            parameters = .init(
                Float(segment.start.x - localOffset.x), Float(segment.start.y - localOffset.y),
                Float(segment.end.x - localOffset.x), Float(segment.end.y - localOffset.y)
            )
            kind = .segment
        case .rhombus(let rhombus):
            let local = rhombus.size ?? .one
            size = .init(Float(local.x), Float(local.y))
            parameters = .init(size.x * 0.5, size.y * 0.5, 0, 0)
            kind = .rhombus
        case .trapezoid(let value):
            size = .init(Float(max(value.bottomWidth, value.topWidth)), Float(value.height))
            parameters = .init(Float(value.bottomWidth * 0.5), Float(value.topWidth * 0.5), Float(value.height * 0.5), 0)
            kind = .trapezoid
        case .parallelogram(let value):
            size = .init(Float(value.width + abs(value.skew)), Float(value.height))
            parameters = .init(Float(value.width * 0.5), Float(value.height * 0.5), Float(value.skew * 0.5), 0)
            kind = .parallelogram
        case .equilateralTriangle(let value):
            let side = Float(value.side ?? 1)
            size = .init(side, side * 0.8660254)
            parameters = .init(side * 0.5, 0, 0, 0)
            kind = .equilateralTriangle
        case .isoscelesTriangle(let value):
            size = .init(Float(value.width), Float(value.height))
            parameters = .init(size.x * 0.5, size.y, 0, 0)
            kind = .isoscelesTriangle
        case .triangle(let value):
            let minimum = SIMD2<Float>(
                Float(min(value.a.x, value.b.x, value.c.x)),
                Float(min(value.a.y, value.b.y, value.c.y))
            )
            let maximum = SIMD2<Float>(
                Float(max(value.a.x, value.b.x, value.c.x)),
                Float(max(value.a.y, value.b.y, value.c.y))
            )
            size = .init(
                max(maximum.x - minimum.x, 0.0001),
                max(maximum.y - minimum.y, 0.0001)
            )
            localOffset = (minimum + maximum) * 0.5
            parameters = .init(
                Float(value.a.x - localOffset.x), Float(value.a.y - localOffset.y),
                Float(value.b.x - localOffset.x), Float(value.b.y - localOffset.y)
            )
            extendedParameters = .init(
                Float(value.c.x - localOffset.x), Float(value.c.y - localOffset.y), 0, 0
            )
            kind = .triangle
        case .unevenCapsule(let value):
            size = .init(Float(max(value.bottomRadius, value.topRadius) * 2), Float(value.height + value.bottomRadius + value.topRadius))
            parameters = .init(Float(value.bottomRadius), Float(value.topRadius), Float(value.height), 0)
            kind = .unevenCapsule
        case .pentagon(let value):
            let radius = Float(value.radius ?? 0.5); size = .init(repeating: radius * 2)
            parameters = .init(radius * 0.809016994, 0, 0, 0); kind = .pentagon
        case .hexagon(let value):
            let radius = Float(value.radius ?? 0.5); size = .init(repeating: radius * 2)
            parameters = .init(radius * 0.866025404, 0, 0, 0); kind = .hexagon
        case .octagon(let value):
            let radius = Float(value.radius ?? 0.5); size = .init(repeating: radius * 2)
            parameters = .init(radius * 0.923879533, 0, 0, 0); kind = .octagon
        case .hexagram(let value):
            let radius = Float(value.radius ?? 0.5); size = .init(repeating: radius * 2)
            parameters = .init(radius * 0.5, 0, 0, 0); kind = .hexagram
        case .star(let value):
            let radius = Float(value.radius); size = .init(repeating: radius * 2)
            parameters = .init(radius, Float(value.points), Float(value.innerRadius), 0); kind = .star
        case .pie(let value):
            let radius = Float(value.radius); size = .init(repeating: radius * 2)
            parameters = .init(radius, Float(value.angle.radians * 0.5), 0, 0); kind = .pie
        case .cutDisk(let value):
            let radius = Float(value.radius); size = .init(repeating: radius * 2)
            parameters = .init(radius, Float(value.height), 0, 0); kind = .cutDisk
        case .arc(let value):
            let extent = Float(value.radius + value.width * 0.5); size = .init(repeating: extent * 2)
            parameters = .init(Float(value.radius), Float(value.angle.radians * 0.5), Float(value.width * 0.5), 0); kind = .arc
        case .ring(let value):
            let extent = Float(value.radius + value.width * 0.5); size = .init(repeating: extent * 2)
            parameters = .init(Float(value.radius), Float(value.width * 0.5), Float(value.direction.x), Float(value.direction.y)); kind = .ring
        case .horseshoe(let value):
            let extent = Float(value.radius + value.length + value.width * 0.5); size = .init(repeating: extent * 2)
            parameters = .init(Float(value.radius), Float(value.angle.radians), Float(value.length), Float(value.width * 0.5)); kind = .horseshoe
        case .vesica(let value):
            let radius = Float(value.radius); size = .init(repeating: radius * 2)
            parameters = .init(radius, Float(value.offset), 0, 0); kind = .vesica
        case .moon(let value):
            let extent = Float(max(value.radius, value.offset + value.cutoutRadius)); size = .init(repeating: extent * 2)
            parameters = .init(Float(value.offset), Float(value.radius), Float(value.cutoutRadius), 0); kind = .moon
        case .roundedCross(let value):
            size = .init(repeating: 2); parameters = .init(Float(value.height), 0, 0, 0); kind = .roundedCross
        case .egg(let value):
            let radius = Float(value.lowerRadius)
            let top = Float(1.7320508075688772 * (value.lowerRadius - value.upperRadius) + value.upperRadius)
            size = .init(radius * 2, radius + top)
            parameters = .init(radius, Float(value.upperRadius), 0, 0); kind = .egg
        case .heart(let value):
            let width = Float(value.width ?? 1)
            let formulaScale = width / 1.207106781
            let height = formulaScale * 1.103553391
            size = .init(width, height)
            parameters = .init(formulaScale, 0, 0, 0); kind = .heart
        case .cross(let value):
            let extent = Float(value.size.x * 2); size = .init(repeating: extent)
            parameters = .init(Float(value.size.x), Float(value.size.y), 0, 0); kind = .cross
        case .roundedX(let value):
            let extent = Float(value.width + value.rounding * 2); size = .init(repeating: extent)
            parameters = .init(Float(value.width), Float(value.rounding), 0, 0); kind = .roundedX
        case .ellipse(let value):
            let local = value.size ?? .one; size = .init(Float(local.x), Float(local.y))
            parameters = .init(size.x * 0.5, size.y * 0.5, 0, 0); kind = .ellipse
        case .parabola(let value):
            size = .init(Float(value.size.x), Float(value.size.y))
            parameters = .init(Float(value.curvature), size.x * 0.5, size.y * 0.5, 0)
            kind = .parabola
        case .parabolaSegment(let value):
            size = .init(Float(value.width), Float(value.height)); parameters = .init(size.x * 0.5, size.y, 0, 0); kind = .parabolaSegment
        case .quadraticBezier(let value):
            let minimum = SIMD2<Float>(
                Float(min(value.start.x, value.control.x, value.end.x)),
                Float(min(value.start.y, value.control.y, value.end.y))
            )
            let maximum = SIMD2<Float>(
                Float(max(value.start.x, value.control.x, value.end.x)),
                Float(max(value.start.y, value.control.y, value.end.y))
            )
            size = .init(
                max(maximum.x - minimum.x, 0.0001),
                max(maximum.y - minimum.y, 0.0001)
            )
            localOffset = (minimum + maximum) * 0.5
            parameters = .init(
                Float(value.start.x - localOffset.x), Float(value.start.y - localOffset.y),
                Float(value.control.x - localOffset.x), Float(value.control.y - localOffset.y)
            )
            extendedParameters = .init(
                Float(value.end.x - localOffset.x), Float(value.end.y - localOffset.y), 0, 0
            )
            kind = .quadraticBezier
        case .blobbyCross(let value):
            size = .init(repeating: 1); parameters = .init(Float(value.height), 0, 0, 0); kind = .blobbyCross
        case .tunnel(let value):
            size = .init(Float(value.width), Float(value.height + value.width * 0.5)); parameters = .init(size.x * 0.5, Float(value.height), 0, 0); kind = .tunnel
        case .stairs(let value):
            size = value.stepSize * Float(value.count)
            parameters = .init(Float(value.stepSize.x), Float(value.stepSize.y), Float(value.count), 0); kind = .stairs
        case .quadraticCircle(let value):
            size = .init(repeating: Float(value.size)); parameters = .init(Float(value.size), 0, 0, 0); kind = .quadraticCircle
        case .hyperbola(let value):
            size = .init(Float(value.size.x), Float(value.size.y))
            parameters = .init(Float(value.scale), size.x * 0.5, size.y * 0.5, 0)
            kind = .hyperbola
        case .coolS(let value):
            size = .init(repeating: Float(value.size)); parameters = .init(Float(value.size), 0, 0, 0); kind = .coolS
        case .circleWave(let value):
            let extent = Float((value.radius + value.width) * 2); size = .init(repeating: extent)
            parameters = .init(Float(value.radius), Float(value.width), 0, 0); kind = .circleWave
        }

        let strokeWidth = shape.strokeColor == nil ? 0 : Float(shape.strokeWidth)
        let strokeAlignment: Float
        let outwardStroke: Float
        switch shape.strokeAlignment {
        case .inside:
            strokeAlignment = -1
            outwardStroke = 0
        case .center:
            strokeAlignment = 0
            outwardStroke = strokeWidth * 0.5
        case .outside:
            strokeAlignment = 1
            outwardStroke = strokeWidth
        }
        let rounding = Float(shape.rounding)
        let quadSize = size + SIMD2(repeating: (outwardStroke + rounding) * 2)
        let transform = sourceTransform.translated(by: localOffset).scaled(
            x: quadSize.x * (shape.isFlipped ? -1 : 1),
            y: quadSize.y
        )
        let transformX = SIMD2(transform.x.x, transform.x.y)
        let transformY = SIMD2(transform.y.x, transform.y.y)
        let translation = SIMD2<Float>(
            transform.translation.x,
            transform.translation.y
        )
        let extent = SIMD2<Float>(
            abs(transformX.x) + abs(transformY.x),
            abs(transformX.y) + abs(transformY.y)
        ) * 0.5

        let fillColor: PixlGraphics.Color
        let gradientLine: SIMD4<Float>
        let gradientPlacement: UInt32
        switch shape.fill {
        case .color(let color):
            fillColor = color
            gradientLine = .zero
            gradientPlacement = 0
        case .gradient(let fill):
            fillColor = .clear
            switch fill.placement {
            case .linear(let start, let end):
                gradientLine = .init(Float(start.x), Float(start.y), Float(end.x), Float(end.y))
                gradientPlacement = 0
            case .radial(let center, let radius):
                gradientLine = .init(Float(center.x), Float(center.y), Float(radius), 0)
                gradientPlacement = 1
            case .angular(let center, let angle):
                gradientLine = .init(Float(center.x), Float(center.y), Float(angle.radians), 0)
                gradientPlacement = 2
            }
        }
        let strokeColor = shape.strokeColor ?? .clear

        self.init(
            boundsMinimum: translation - extent,
            boundsMaximum: translation + extent,
            transformX: transformX,
            transformY: transformY,
            transformTranslation: translation,
            quadHalfExtent: quadSize * 0.5,
            parameters: parameters,
            extendedParameters: extendedParameters,
            fillColor: fillColor.premultiplied,
            gradientSlot: gradientSlot,
            gradientLine: gradientLine,
            gradientPlacement: gradientPlacement,
            strokeColor: strokeColor.premultiplied,
            kind: kind,
            strokeWidth: strokeWidth,
            strokeAlignment: strokeAlignment,
            smoothAntialiasing: shape.antialiasing == .smooth ? 1 : 0,
            rounding: rounding,
            blendMode: shape.blendMode.platform,
            layer: shape.layer.rawValue,
            order: shape.order
        )
    }
}

private extension PixlGraphics.Color {
    var premultiplied: SIMD4<Float> {
        .init(red * opacity, green * opacity, blue * opacity, opacity)
    }
}

private extension Sprite.Material.BlendMode {
    var platform: BlendMode {
        switch self {
        case .normal: .premultiplied
        case .replace: .replace
        }
    }
}

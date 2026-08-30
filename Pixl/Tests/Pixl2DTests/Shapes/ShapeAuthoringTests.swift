import Pixl2D
import PixlGraphics
import Testing

@Suite("Shape authoring")
struct ShapeAuthoringTests {
    @Test
    func leadingDotGeometryMatchesExplicitGeometry() {
        #expect(Shape(.circle) == Shape(Circle()))
        #expect(Shape(.circle(radius: 20)) == Shape(Circle(radius: 20)))
        #expect(Shape(.rect, rounding: 8) == Shape(Rectangle(), rounding: 8))
    }

    @Test
    func defaultsMatchOrdinaryShapeRendering() {
        let shape = Shape(.circle)

        #expect(shape.fill == .color(.white))
        #expect(shape.stroke == nil)
        #expect(shape.antialiasing == .smooth)
        #expect(shape.rounding == 0)
    }

    @Test
    func modifiersReturnIndependentValues() {
        let original = Shape(.rect)
        let styled = original
            .fill(.red)
            .stroke(.white, width: 2, alignment: .inside)
            .rounding(3)
            .antialiasing(.hard)

        #expect(original.fill == .color(.white))
        #expect(original.stroke == nil)
        #expect(styled.fill == .color(.red))
        #expect(styled.stroke?.color == .white)
        #expect(styled.stroke?.width == 2)
        #expect(styled.stroke?.alignment == .inside)
        #expect(styled.rounding == 3)
        #expect(styled.antialiasing == .hard)
    }

    @Test
    func gradientFillRetainsItsRampAndDirection() {
        let gradient = Gradient(colors: [.red, .blue])
        let shape = Shape(.circle)
            .fill(gradient, from: .init(0, -0.5), to: .init(0, 0.5))

        guard case .gradient(let fill) = shape.fill else {
            Issue.record("Expected a gradient fill")
            return
        }
        #expect(fill.gradient == gradient)
        #expect(fill.placement == .linear(from: .init(0, -0.5), to: .init(0, 0.5)))
    }

    @Test
    func radialAndAngularGradientPlacementsAreRetained() {
        let gradient = Gradient(colors: [.red, .blue])
        let radial = Shape(.circle).fill(gradient, center: .init(1, 2), radius: 3)
        let angular = Shape(.circle).fill(gradient, center: .init(4, 5), angle: .degrees(90))

        guard case .gradient(let radialFill) = radial.fill,
              case .gradient(let angularFill) = angular.fill else {
            Issue.record("Expected gradient fills")
            return
        }
        #expect(radialFill.placement == .radial(center: .init(1, 2), radius: 3))
        #expect(angularFill.placement == .angular(center: .init(4, 5), angle: .degrees(90)))
    }

    @Test
    func everyFixedGeometryIsConstructible() {
        let shapes: [Shape] = [
            Shape(.circle), Shape(.rect), Shape(.segment), Shape(.rhombus),
            Shape(.trapezoid), Shape(.parallelogram), Shape(.equilateralTriangle),
            Shape(.isoscelesTriangle), Shape(.triangle), Shape(.unevenCapsule),
            Shape(.pentagon), Shape(.hexagon), Shape(.octagon), Shape(.hexagram),
            Shape(.star), Shape(.pie), Shape(.cutDisk), Shape(.arc), Shape(.ring),
            Shape(.horseshoe), Shape(.vesica), Shape(.moon), Shape(.roundedCross),
            Shape(.egg), Shape(.heart), Shape(.cross), Shape(.roundedX),
            Shape(.ellipse), Shape(.parabola), Shape(.parabolaSegment),
            Shape(.quadraticBezier), Shape(.blobbyCross), Shape(.tunnel),
            Shape(.stairs), Shape(.quadraticCircle), Shape(.hyperbola),
            Shape(.coolS), Shape(.circleWave),
        ]

        #expect(shapes.count == 38)
    }

    @Test
    func collisionGeometryCanBeRenderedAnalytically() {
        let circle = Circle2D(center: .init(2, 3), radius: 4)
        let capsule = Capsule2D(
            segment: .init(start: .init(-2, -1), end: .init(3, 4)),
            radius: 2
        )

        #expect(Shape(circle).geometry == .circle2D(circle))
        #expect(Shape(capsule).geometry == .capsule2D(capsule))
    }
}

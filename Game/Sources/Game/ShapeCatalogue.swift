import Pixl
import Pixl2D

/// Temporary visual diagnostic for the fixed-parameter IQ shape catalogue.
struct ShapeCatalogue {
    private static let columns = 5
    private static let rows = 8
    // Leaves room for the tallest canonical geometry, outward rounding, and a
    // fully outside stroke so the grid reveals shape clipping rather than
    // introducing viewport or neighbouring-cell clipping of its own.
    private static let shapeScale: Float = 48

    private let bindings: ShapeBindings = .init()
    private var alignment: Shape.StrokeAlignment = .center
    private var rounding: Float = 0

    init(context: GameContext) {
//        bindings.bind(to: context.inputs)
    }

    // Row-major, following the IQ article while omitting deliberately absent
    // duplicate/special cases: separate box/oriented-box/star-5 and polygon.
    private var shapes: [Shape] = [
        // Row 1: 1...5
        Shape(.circle),
        Shape(.rect),
        Shape(.segment),
        Shape(.rhombus),
        Shape(.trapezoid),

        // Row 2: 6...10
        Shape(.parallelogram),
        Shape(.equilateralTriangle),
        Shape(.isoscelesTriangle),
        Shape(.triangle),
        Shape(.unevenCapsule),

        // Row 3: 11...15
        Shape(.pentagon),
        Shape(.hexagon),
        Shape(.octagon),
        Shape(.hexagram),
        Shape(.star),

        // Row 4: 16...20
        Shape(.pie),
        Shape(.cutDisk),
        Shape(.arc),
        Shape(.ring),
        Shape(.horseshoe),

        // Row 5: 21...25
        Shape(.vesica),
        Shape(.moon),
        Shape(.roundedCross),
        Shape(.egg),
        Shape(.heart),

        // Row 6: 26...30
        Shape(.cross),
        Shape(.roundedX),
        Shape(.ellipse),
        Shape(.parabola),
        Shape(.parabolaSegment),

        // Row 7: 31...35
        Shape(.quadraticBezier),
        Shape(.blobbyCross),
        Shape(.tunnel),
        Shape(.stairs),
        Shape(.quadraticCircle),

        // Row 8: 36...38
        Shape(.hyperbola),
        Shape(.coolS),
        Shape(.circleWave),
    ].map {
        var shape = $0
            .fill(.clear)
            .stroke(.blue, width: 2 / shapeScale, alignment: .center)
//            .rounding(0.2)
        shape.layer = 1
        return shape
    }

    mutating func update(_ time: UpdateTime, context: GameContext) {
        if bindings.inside.is(.down) {
            alignment = .inside
        } else if bindings.center.is(.down) {
            alignment = .center
        } else if bindings.outside.is(.down) {
            alignment = .outside
        }

        if bindings.up.is(.up) {
            rounding += 0.01
        }

        if bindings.down.is(.down) {
            rounding = max(0, rounding - 0.01)
        }

        for index in shapes.indices {
            shapes[index].strokeAlignment = alignment
            shapes[index].rounding = rounding
        }
    }

    func submit(to context: GameContext, in size: Size) {
        let cellWidth = size.width / Float(Self.columns)
        let cellHeight = size.height / Float(Self.rows)

        for (index, shape) in shapes.enumerated() {
            let column = index % Self.columns
            let row = index / Self.columns
            let position = Vec2(
                (Float(column) + 0.5) * cellWidth,
                (Float(row) + 0.5) * cellHeight
            )

            var shape = shape
            shape.strokeWidth = 2 / Self.shapeScale

            context.submit(
                shape,
                transform: .init(
                    position,
                    scale: .init(Self.shapeScale, -Self.shapeScale)
                ),
                in: .screen
            )
        }

        for column in 0...Self.columns {
            let x = Float(column) * cellWidth
            var line = Shape(.segment(
                from: .init(x, 0),
                to: .init(x, size.height)
            )).stroke(.opaqueSeparator, width: 1)
            line.layer = 2
            context.submit(line, transform: .identity, in: .screen)
        }

        for row in 0...Self.rows {
            let y = Float(row) * cellHeight
            var line = Shape(.segment(
                from: .init(0, y),
                to: .init(size.width, y)
            )).stroke(.opaqueSeparator, width: 1)
            line.layer = 2
            context.submit(line, transform: .identity, in: .screen)
        }
    }
}

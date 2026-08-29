import Pixl2D
import PixlFoundation
import PixlGraphics
import Testing
@testable import Pixl

@Suite("Immediate primitive shapes")
struct PrimitiveShapeTests {
    @Test
    func lowersRectangleFillAndLogicalStroke() {
        let rect = Rect(x: -10, y: -5, width: 20, height: 10)
        let transform = Transform2D(.init(100, 50), scale: .init(2, 3))

        let fill = PrimitiveSubmission(
            shape: .rect(rect),
            transform: transform,
            style: .fill(.blue.opacity(0.5)),
            layer: 3,
            order: 7
        )
        let stroke = PrimitiveSubmission(
            shape: .rect(rect),
            transform: transform,
            style: .stroke(.yellow, width: 2),
            layer: 3,
            order: 8
        )

        #expect(fill.kind == .rectFill)
        #expect(fill.color == .init(
            Color.blue.red * 0.5,
            Color.blue.green * 0.5,
            Color.blue.blue * 0.5,
            0.5
        ))
        #expect(stroke.kind == .rectStroke)
        #expect(stroke.width == 2)
        #expect(fill.layer == 3)
        #expect(fill.order == 7)
        #expect(fill.boundsMinimum == .init(80, 35))
        #expect(fill.boundsMaximum == .init(120, 65))
    }

    @Test
    func ellipseUsesSharedPrimitiveFamilyAndKindBatches() {
        let queue = RenderQueue(settings: .init(capacity: 4))
        let rect = Rect(x: 0, y: 0, width: 20, height: 10)
        queue.submit(PrimitiveSubmission(
            shape: .ellipse(in: rect),
            transform: .identity,
            style: .fill(.blue),
            layer: 0,
            order: 0
        ))
        queue.submit(PrimitiveSubmission(
            shape: .ellipse(in: rect),
            transform: .identity,
            style: .stroke(.yellow, width: 1),
            layer: 0,
            order: 1
        ))
        var view = RenderQueue.View(
            projectionX: .init(1, 0, 0),
            projectionY: .init(0, 1, 0),
            projectionTranslation: .init(0, 0, 1),
            logicalSize: .init(200, 100),
            boundsMinimum: .init(repeating: -100),
            boundsMaximum: .init(repeating: 100)
        )

        withUnsafePointer(to: &view) { pointer in
            queue.execute(views: .init(start: pointer, count: 1)) { execution in
                #expect(execution.views[0].logicalSize == .init(200, 100))
                #expect(execution.views[0].batches.count == 2)
                #expect(execution.views[0].batches[0].family == .primitive)
                #expect(execution.views[0].batches[0].material == PrimitiveKind.ellipseFill.rawValue)
                #expect(execution.views[0].batches[1].family == .primitive)
                #expect(execution.views[0].batches[1].material == PrimitiveKind.ellipseStroke.rawValue)
            }
        }
    }

    @Test
    func primitiveInstanceRemainsCompact() {
        #expect(MemoryLayout<RenderQueue.PrimitiveInstance>.stride == 48)
    }
}

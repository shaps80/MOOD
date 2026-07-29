import XCTest
@testable import PixlUI

final class PixlUIPerformanceTests: XCTestCase {
    func testMeasurementBaseline() {
        var observation = 0

        measure(metrics: metrics()) {
            observation &+= 1
        }

        XCTAssertGreaterThan(observation, 0)
    }

    func testImmediate8192ElementLayout() {
        var observation = 0

        measure(metrics: metrics()) {
            let root = ViewGraph.build { BenchmarkLayout() }
            let layout = root.layout(in: BenchmarkLayout.viewport)
            observation &+= root.graph.nodes.count
            observation &+= layout.frames.count
        }

        XCTAssertGreaterThan(observation, 0)
    }

    func testRetained8192ElementLayout() throws {
        let scene = Scene(BenchmarkLayout())
        _ = try scene.prepare(
            size: BenchmarkLayout.viewport,
            displayScale: 1,
            resolveImage: { _ in fatalError("Benchmark has no images") }
        )
        var observation = 0

        measure(metrics: metrics()) {
            let prepared = try! scene.prepare(
                size: BenchmarkLayout.viewport,
                displayScale: 1,
                resolveImage: { _ in fatalError("Benchmark has no images") }
            )
            observation &+= prepared.root.graph.nodes.count
            observation &+= prepared.layout.frames.count
        }

        XCTAssertGreaterThan(observation, 0)
    }

    func testFixtureCounts() {
        let root = ViewGraph.build { BenchmarkLayout() }
        let layout = root.layout(in: BenchmarkLayout.viewport)

        XCTAssertEqual(root.graph.shapes.count, 4_096)
        XCTAssertEqual(root.graph.primitives.count, 4_096)
        XCTAssertEqual(root.graph.layouts.count, 4_225)
        XCTAssertEqual(root.graph.nodes.count, 12_417)
        XCTAssertEqual(layout.frames.count, root.graph.nodes.count)
    }

    private func metrics() -> [any XCTMetric] {
        [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]
    }
}

private struct BenchmarkLayout: View {
    typealias Body = Never

    static let viewport = Size(width: 1_024, height: 768)
    static let rowCount = 128
    static let cellsPerRow = 32

    static func _makeView(
        view: _GraphValue<Self>,
        inputs: _ViewInputs
    ) -> _ViewOutputs {
        let root = appendLayout(VStackLayout(spacing: 2), to: inputs)

        for row in 0..<rowCount {
            let rowNode = appendLayout(
                HStackLayout(alignment: row.isMultiple(of: 2) ? .top : .bottom, spacing: 2),
                to: childInputs(parent: root, from: inputs)
            )

            for column in 0..<cellsPerRow {
                let cell = appendLayout(
                    ZStackLayout(alignment: (row + column).isMultiple(of: 2) ? .center : .bottomTrailing),
                    to: childInputs(parent: rowNode, from: inputs)
                )
                let cellInputs = childInputs(parent: cell, from: inputs)
                _ = Rectangle(cornerRadius: Float((row + column) % 9))._makeView(inputs: cellInputs)
                _ = Text("R\(row) C\(column)")._makeView(inputs: cellInputs)
            }
        }

        return .init(node: root)
    }

    private static func appendLayout<L: Layout>(
        _ layout: L,
        to inputs: _ViewInputs
    ) -> ViewGraph.NodeID {
        let payload = Int32(inputs.graph.layouts.count)
        inputs.graph.layouts.append(.init(box: _LayoutBox(layout)))
        return inputs.graph.appendNode(
            kind: .layout,
            payload: payload,
            parent: inputs.parent
        )
    }

    private static func childInputs(
        parent: ViewGraph.NodeID,
        from inputs: _ViewInputs
    ) -> _ViewInputs {
        .init(
            graph: inputs.graph,
            parent: parent,
            environment: inputs.environment
        )
    }
}

private extension View {
    func _makeView(inputs: _ViewInputs) -> _ViewOutputs {
        Self._makeView(view: .init(self, graph: inputs.graph), inputs: inputs)
    }
}

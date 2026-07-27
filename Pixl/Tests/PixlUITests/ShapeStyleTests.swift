import Testing
@testable import PixlUI

@Suite struct ShapeStyleTests {
    @Test func opacityMultipliesResolvedColorOpacity() {
        let root = ViewGraph.build {
            Rectangle()
                .foregroundStyle(.fill.opacity(0.5).opacity(0.5))
        }
        var expected = Color.fill
        expected.opacity *= 0.25

        #expect(root.graph.styles.contains(.color(expected)))
    }

    @Test func opacityAppliesAfterEnvironmentStyleResolution() {
        let root = ViewGraph.build {
            Rectangle()
                .foregroundStyle(.background.tertiary.opacity(0.5))
        }

        #expect(root.graph.styles.contains(.color(Color.background.opacity(0.15))))
    }
}

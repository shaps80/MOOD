import Testing
@testable import PixlUI

@Suite struct FrameLayoutTests {
    @Test func finiteMaximumExpandsToMaximumWithinLargerProposal() {
        let root = ViewGraph.build {
            Text("ds")
                .frame(maxWidth: 200)
        }

        let layout = root.layout(in: .init(width: 500, height: 100))

        #expect(layout.frames[0].size.width == 200)
    }

    @Test func finiteMaximumUsesSmallerParentProposal() {
        let root = ViewGraph.build {
            Text("ds")
                .frame(maxWidth: 200)
        }

        let layout = root.layout(in: .init(width: 100, height: 100))

        #expect(layout.frames[0].size.width == 100)
    }

    @Test func unconstrainedAxisFitsContent() {
        let root = ViewGraph.build {
            Text("ds")
                .frame(maxWidth: 200)
        }

        let layout = root.layout(in: .init(width: 500, height: 100))

        #expect(layout.frames[0].size.height == 30)
    }

    @Test func horizontalStackAllocatesByFlexibility() {
        let root = ViewGraph.build {
            HStack(spacing: 0) {
                Text("ds")
                Text("bounded")
                    .frame(maxWidth: 200)
            }
        }

        let layout = root.layout(in: .init(width: 500, height: 100))

        #expect(layout.frames[0].size.width == 240)
    }

    @Test func spacerConsumesRemainingStackWidth() {
        let root = ViewGraph.build {
            HStack(spacing: 0) {
                Text("ds")
                Spacer()
            }
        }

        let layout = root.layout(in: .init(width: 500, height: 100))

        #expect(layout.frames[0].size.width == 500)
    }
}

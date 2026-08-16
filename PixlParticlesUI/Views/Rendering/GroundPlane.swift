import PixlParticles
import SwiftUI

struct GroundPlane {
    enum Style: Hashable {
        case grid
        case horizon
    }

    let height: Float
    let extent: Float
    let spacing: Float

    func path(
        in viewport: Camera.Viewport,
        style: Style
    ) -> Path {
        switch style {
        case .grid:
            gridPath(in: viewport)
        case .horizon:
            horizonPath(in: viewport)
        }
    }

    private func gridPath(in viewport: Camera.Viewport) -> Path {
        var path = Path()
        var coordinate = -extent

        while coordinate <= extent {
            if let line = viewport.projectLine(
                from: [-extent, height, coordinate],
                to: [extent, height, coordinate]
            ) {
                path.move(to: line.start)
                path.addLine(to: line.end)
            }

            if let line = viewport.projectLine(
                from: [coordinate, height, -extent],
                to: [coordinate, height, extent]
            ) {
                path.move(to: line.start)
                path.addLine(to: line.end)
            }

            coordinate += spacing
        }

        return path
    }

    private func horizonPath(in viewport: Camera.Viewport) -> Path {
        var path = Path()

        if let line = viewport.projectLine(
            from: [-extent, height, 0],
            to: [extent, height, 0]
        ) {
            path.move(to: line.start)
            path.addLine(to: line.end)
        }

        return path
    }
}

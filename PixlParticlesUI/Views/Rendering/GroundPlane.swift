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
            if
                let start = viewport.project([-extent, height, coordinate]),
                let end = viewport.project([extent, height, coordinate])
            {
                path.move(to: start)
                path.addLine(to: end)
            }

            if
                let start = viewport.project([coordinate, height, -extent]),
                let end = viewport.project([coordinate, height, extent])
            {
                path.move(to: start)
                path.addLine(to: end)
            }

            coordinate += spacing
        }

        return path
    }

    private func horizonPath(in viewport: Camera.Viewport) -> Path {
        var path = Path()

        if
            let start = viewport.project([-extent, height, 0]),
            let end = viewport.project([extent, height, 0])
        {
            path.move(to: start)
            path.addLine(to: end)
        }

        return path
    }
}

import PixlParticles
import SwiftUI

struct GroundPlane {
    let height: Float
    let extent: Float
    let spacing: Float

    func path(in viewport: Camera.Viewport) -> Path {
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
}

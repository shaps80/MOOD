import Foundation
import PixlParticles

enum SpawnPreset: CaseIterable, Hashable {
    case point
    case line
    case plane
    case box
    case sphere

    var title: LocalizedStringResource {
        switch self {
        case .point: "Point"
        case .line: "Line"
        case .plane: "Plane"
        case .box: "Box"
        case .sphere: "Sphere"
        }
    }

    var region: SpawnRegion {
        switch self {
        case .point:
            .point(.zero)
        case .line:
            .line(from: [-100, 0, 0], to: [100, 0, 0])
        case .plane:
            .box(size: [200, 0, 200])
        case .box:
            .box(size: [200, 200, 200])
        case .sphere:
            .sphere(radius: 150)
        }
    }
}

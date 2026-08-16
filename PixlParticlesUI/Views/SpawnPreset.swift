import Foundation
import PixlParticles

enum SpawnPreset: CaseIterable, Hashable {
    case point
    case line
    case plane
    case cube
    case sphere

    var title: LocalizedStringResource {
        switch self {
        case .point: "Point"
        case .line: "Line"
        case .plane: "Plane"
        case .cube: "Cube"
        case .sphere: "Sphere"
        }
    }

    var supportedDomains: [SpawnRegion.Domain] {
        switch self {
        case .cube, .sphere:
            [.volume, .surface]
        case .point, .line, .plane:
            [.volume]
        }
    }

    func region(domain: SpawnRegion.Domain) -> SpawnRegion {
        switch self {
        case .point:
            .point(.zero)
        case .line:
            .line(from: [-100, 0, 0], to: [100, 0, 0])
        case .plane:
            .cube(size: [200, 0, 200])
        case .cube:
            .cube(size: [200, 200, 200], domain: domain)
        case .sphere:
            .sphere(radius: 150, domain: domain)
        }
    }
}

extension SpawnRegion.Domain {
    var title: LocalizedStringResource {
        switch self {
        case .volume: "Volume"
        case .surface: "Surface"
        }
    }
}

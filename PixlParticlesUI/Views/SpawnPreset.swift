import Foundation
import PixlParticles

enum SpawnPreset: String, Codable, CaseIterable, Hashable, Sendable {
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

    var supportedDomains: [ParticleDocument.SpawnDomain] {
        switch self {
        case .cube, .sphere:
            [.volume, .surface]
        case .point, .line, .plane:
            [.volume]
        }
    }

    func region(domain: ParticleDocument.SpawnDomain) -> SpawnRegion {
        switch self {
        case .point:
            .point(.zero)
        case .line:
            .line(from: [-100, 0, 0], to: [100, 0, 0])
        case .plane:
            .cube(size: [200, 0, 200])
        case .cube:
            .cube(size: [200, 200, 200], domain: domain.regionDomain)
        case .sphere:
            .sphere(radius: 150, domain: domain.regionDomain)
        }
    }
}

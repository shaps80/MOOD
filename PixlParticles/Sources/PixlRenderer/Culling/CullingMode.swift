import Swift

enum CullingMode: UInt32 {
    case point
    case worldBillboard
    case screenBillboard

    init(renderer: ParticleRenderer) {
        switch (renderer.mode, renderer.billboard.sizeSpace) {
        case (.point, _): self = .point
        case (.billboard, .world): self = .worldBillboard
        case (.billboard, .screen): self = .screenBillboard
        }
    }
}


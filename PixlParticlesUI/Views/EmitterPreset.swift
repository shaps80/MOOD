import Foundation
import PixlParticles

enum EmitterPreset: String, CaseIterable, Hashable, Sendable {
    case debris

    var title: LocalizedStringResource {
        switch self {
        case .debris: "Debris"
        }
    }

    func emitter(capacity: Int = 10_000) -> Emitter {
        switch self {
        case .debris:
            var emitter = Emitter(
                capacity: capacity,
                spawnRegion: .sphere(radius: 150, domain: .surface)
            )
            emitter[\.velocity].append(
                .set(
                    .random(
                        from: [-20, -20, -20],
                        to: [20, 20, 20],
                        variation: .perValue
                    )
                )
            )
            emitter[\.color].append(.set(.white))
            emitter[\.size].append(.set([1, 2]))
            emitter[\.rotation].append(.set(0))
            return emitter
        }
    }
}

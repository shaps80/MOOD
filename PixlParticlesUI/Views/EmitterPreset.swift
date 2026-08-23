import Foundation
import PixlParticles

enum EmitterPreset: String, CaseIterable, Hashable, Sendable {
    case debris

    var title: LocalizedStringResource {
        switch self {
        case .debris: "Debris"
        }
    }

    func emitter() -> Emitter {
        switch self {
        case .debris:
            var emitter = Emitter(
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

extension Emitter {
    func applying(_ snapshot: ParticleDocument.Snapshot) -> Self {
        var emitter = self

        emitter.spawnRate = .init([
            .set(Float(snapshot.spawnRate)),
        ])
        emitter.lifetime = .init([
            .set(Float(snapshot.lifetime)),
        ])
        emitter.spawnRegion = snapshot.spawnPreset.region(
            domain: snapshot.spawnDomain
        )
        emitter.color = .init([.set(snapshot.color)])
        emitter.size = .init([
            .set([
                max(Float(snapshot.billboardWidth), 0),
                max(Float(snapshot.billboardHeight), 0),
            ]),
        ])
        emitter.rotation = .init([
            .set(Float(snapshot.billboardRotation)),
        ])
        emitter.renderers = [snapshot.renderer]
        return emitter
    }
}

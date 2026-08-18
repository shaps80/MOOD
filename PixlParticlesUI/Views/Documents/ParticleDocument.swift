import Observation
import PixlParticles
import SwiftUI

@Observable
final class ParticleDocument: Document {
    enum SpawnDomain: String, Codable, Hashable, Sendable {
        case volume
        case surface

        var title: LocalizedStringResource {
            switch self {
            case .volume: "Volume"
            case .surface: "Surface"
            }
        }

        var regionDomain: SpawnRegion.Domain {
            switch self {
            case .volume: .volume
            case .surface: .surface
            }
        }
    }

    struct Snapshot: Codable, Equatable, Sendable {
        var duration: Double
        var particleCount: Double
        var seed: Double
        var color: PixlParticles.Color
        var spawnPreset: SpawnPreset
        var spawnDomain: SpawnDomain
        var isLODEnabled: Bool
        var lodActivation: Double
        var lodMaximum: Double
        var lodTileSize: Double
        var lodPointsPerPixel: Double
        var isCullingEnabled: Bool
        var cullingBoundsScale: Double

        init(
            duration: Double = 30,
            particleCount: Double = 10_000,
            seed: Double = 0,
            color: PixlParticles.Color = .white,
            spawnPreset: SpawnPreset = .sphere,
            spawnDomain: SpawnDomain = .surface,
            isLODEnabled: Bool = false,
            lodActivation: Double = 500_000,
            lodMaximum: Double = 1_000_000,
            lodTileSize: Double = 16,
            lodPointsPerPixel: Double = 1,
            isCullingEnabled: Bool = true,
            cullingBoundsScale: Double = 300
        ) {
            self.duration = duration
            self.particleCount = particleCount
            self.seed = seed
            self.color = color
            self.spawnPreset = spawnPreset
            self.spawnDomain = spawnDomain
            self.isLODEnabled = isLODEnabled
            self.lodActivation = lodActivation
            self.lodMaximum = lodMaximum
            self.lodTileSize = lodTileSize
            self.lodPointsPerPixel = lodPointsPerPixel
            self.isCullingEnabled = isCullingEnabled
            self.cullingBoundsScale = cullingBoundsScale
        }

        init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            duration = try values.decode(Double.self, forKey: .duration)
            particleCount = try values.decode(Double.self, forKey: .particleCount)
            seed = try values.decode(Double.self, forKey: .seed)
            color = try values.decodeIfPresent(
                PixlParticles.Color.self,
                forKey: .color
            ) ?? .white
            spawnPreset = try values.decode(SpawnPreset.self, forKey: .spawnPreset)
            spawnDomain = try values.decode(SpawnDomain.self, forKey: .spawnDomain)
            isLODEnabled = try values.decode(Bool.self, forKey: .isLODEnabled)
            lodActivation = try values.decode(Double.self, forKey: .lodActivation)
            lodMaximum = try values.decode(Double.self, forKey: .lodMaximum)
            lodTileSize = try values.decode(Double.self, forKey: .lodTileSize)
            lodPointsPerPixel = try values.decode(
                Double.self,
                forKey: .lodPointsPerPixel
            )
            isCullingEnabled = try values.decode(
                Bool.self,
                forKey: .isCullingEnabled
            )
            cullingBoundsScale = try values.decode(
                Double.self,
                forKey: .cullingBoundsScale
            )
        }
    }

    private(set) var snapshot: Snapshot

    init(snapshot: Snapshot = .init()) {
        self.snapshot = snapshot
    }

    func replace(with snapshot: Snapshot) {
        self.snapshot = snapshot
    }

    func performEdit(
        actionName: String,
        undoManager: UndoManager?,
        _ edit: (inout Snapshot) -> Void
    ) {
        let before = snapshot
        var after = before
        edit(&after)
        guard before != after else { return }

        snapshot = after
        guard let undoManager else { return }
        registerUndo(
            restoring: before,
            inverse: after,
            actionName: actionName,
            undoManager: undoManager
        )
    }

    func binding<Value>(
        _ keyPath: WritableKeyPath<Snapshot, Value>,
        actionName: String,
        undoManager: UndoManager?
    ) -> Binding<Value> {
        Binding(
            get: { self.snapshot[keyPath: keyPath] },
            set: { value in
                self.performEdit(
                    actionName: actionName,
                    undoManager: undoManager
                ) { snapshot in
                    snapshot[keyPath: keyPath] = value
                }
            }
        )
    }

    private func registerUndo(
        restoring snapshot: Snapshot,
        inverse: Snapshot,
        actionName: String,
        undoManager: UndoManager
    ) {
        undoManager.registerUndo(withTarget: self) { document in
            document.snapshot = snapshot
            document.registerUndo(
                restoring: inverse,
                inverse: snapshot,
                actionName: actionName,
                undoManager: undoManager
            )
        }
        undoManager.setActionName(actionName)
    }
}

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
        var spawnPreset: SpawnPreset
        var spawnDomain: SpawnDomain
        var isLODEnabled: Bool
        var lodActivation: Double
        var lodMaximum: Double
        var lodTileSize: Double
        var lodPointsPerPixel: Double
        var areCullingBoundsEnabled: Bool
        var cullingBoundsScale: Double

        init(
            duration: Double = 30,
            particleCount: Double = 10_000,
            seed: Double = 0,
            spawnPreset: SpawnPreset = .sphere,
            spawnDomain: SpawnDomain = .surface,
            isLODEnabled: Bool = false,
            lodActivation: Double = 500_000,
            lodMaximum: Double = 1_000_000,
            lodTileSize: Double = 16,
            lodPointsPerPixel: Double = 1,
            areCullingBoundsEnabled: Bool = true,
            cullingBoundsScale: Double = 300
        ) {
            self.duration = duration
            self.particleCount = particleCount
            self.seed = seed
            self.spawnPreset = spawnPreset
            self.spawnDomain = spawnDomain
            self.isLODEnabled = isLODEnabled
            self.lodActivation = lodActivation
            self.lodMaximum = lodMaximum
            self.lodTileSize = lodTileSize
            self.lodPointsPerPixel = lodPointsPerPixel
            self.areCullingBoundsEnabled = areCullingBoundsEnabled
            self.cullingBoundsScale = cullingBoundsScale
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

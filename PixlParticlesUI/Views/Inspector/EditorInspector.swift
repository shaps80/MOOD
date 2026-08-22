import SwiftUI
import PixlParticles
import PixlRenderer

struct EditorInspector: View {
    @Environment(\.undoManager) private var undoManager

    @Bindable var document: ParticleDocument
    @Binding var system: System
    @Binding var playback: PlaybackState

    var body: some View {
        Inspector {
            SystemInspectorSection(
                duration: binding(\.duration, "Change Duration"),
                particleCount: binding(\.particleCount, "Change Particle Count"),
                seed: binding(\.seed, "Change Seed")
            )

            SpawnInspectorSection(
                preset: binding(\.spawnPreset, "Change Spawn Region"),
                domain: binding(\.spawnDomain, "Change Spawn Domain")
            )

            ColorInspectorSection(
                color: binding(\.color, "Change Colour")
            )

            RenderingInspectorSection(
                mode: binding(\.renderer.mode, "Change Render Mode"),
                sizeSpace: binding(
                    \.renderer.billboard.sizeSpace,
                     "Change Billboard Size Space"
                ),
                facing: binding(
                    \.renderer.billboard.facing,
                     "Change Billboard Facing"
                ),
                width: binding(
                    \.billboardWidth,
                     "Change Billboard Width"
                ),
                height: binding(
                    \.billboardHeight,
                     "Change Billboard Height"
                ),
                rotation: binding(
                    \.billboardRotation,
                     "Change Billboard Rotation"
                )
            )

            if document.snapshot.renderer.mode == .point {
                PointLODInspectorSection(
                    isEnabled: binding(\.isLODEnabled, "Toggle LOD"),
                    activation: binding(\.lodActivation, "Change LOD Activation"),
                    maximum: binding(\.lodMaximum, "Change LOD Maximum"),
                    tileSize: binding(\.lodTileSize, "Change LOD Tile Size"),
                    pointsPerPixel: binding(\.lodPointsPerPixel, "Change LOD Density")
                )
            }

            CullingInspectorSection(
                isEnabled: binding(
                    \.isCullingEnabled, "Toggle Culling Bounds"),
                scale: binding(\.cullingBoundsScale, "Change Culling Bounds")
            )
        }
        .onChange(of: document.snapshot.color) {
            updateSystem()
        }
        .onChange(of: document.snapshot.spawnPreset) {
            updateSystem()
        }
        .onChange(of: document.snapshot.spawnDomain) {
            updateSystem()
        }
        .onChange(of: document.snapshot.duration) { _, duration in
            let duration = max(duration, 0)

            if document.snapshot.duration != duration {
                edit("Change Duration") { $0.duration = duration }
            }
        }
        .onChange(of: document.snapshot.particleCount) { _, particleCount in
            let particleCount = max(particleCount.rounded(), 0)

            if document.snapshot.particleCount != particleCount {
                edit("Change Particle Count") { $0.particleCount = particleCount }
            } else {
                updateSystem()
            }
        }
        .onChange(of: document.snapshot.seed) { _, seed in
            let maximumExactInteger = 9_007_199_254_740_991.0
            let seed = min(max(seed.rounded(), 0), maximumExactInteger)

            if document.snapshot.seed != seed {
                edit("Change Seed") { $0.seed = seed }
            } else {
                updateSystem()
            }
        }
    }

    private func updateSystem() {
        let snapshot = document.snapshot
        system = System(
            seed: UInt64(snapshot.seed),
            emitter: EmitterPreset.debris.emitter()
                .applying(document.snapshot),
            duration: .seconds(snapshot.duration),
            storesRewindState: false
        )
        playback.fraction = 0
    }

    private func binding<Value>(
        _ keyPath: WritableKeyPath<ParticleDocument.Snapshot, Value>,
        _ actionName: String
    ) -> Binding<Value> {
        document.binding(
            keyPath,
            actionName: actionName,
            undoManager: undoManager
        )
    }

    private func edit(
        _ actionName: String,
        _ edit: (inout ParticleDocument.Snapshot) -> Void
    ) {
        document.performEdit(
            actionName: actionName,
            undoManager: undoManager,
            edit
        )
    }
}

import SwiftUI
import PixlParticles
import PixlRenderer

struct PropertiesInspector: View {
    @Environment(\.undoManager) private var undoManager

    @Bindable var document: ParticleDocument

    var body: some View {
        Inspector {
            SystemInspectorSection(
                duration: binding(\.duration, "Change Duration"),
                spawnRate: binding(\.spawnRate, "Change Spawn Rate"),
                lifetime: binding(\.lifetime, "Change Lifetime"),
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

}

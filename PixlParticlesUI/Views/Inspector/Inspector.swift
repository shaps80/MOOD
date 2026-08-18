import SwiftUI
import PixlParticles
import PixlRenderer

struct Inspector: View {
    @Binding var duration: Double
    @Binding var particleCount: Double
    @Binding var seed: Double
    @Binding var color: PixlParticles.Color
    @Binding var spawnPreset: SpawnPreset
    @Binding var spawnDomain: ParticleDocument.SpawnDomain
    @Binding var renderMode: ParticleRenderer.Mode
    @Binding var billboardSizeSpace: BillboardRenderer.SizeSpace
    @Binding var billboardFacing: BillboardRenderer.Facing
    @Binding var billboardWidth: Double
    @Binding var billboardHeight: Double
    @Binding var billboardRotation: Double
    @Binding var lodEnabled: Bool
    @Binding var lodActivation: Double
    @Binding var lodMaximum: Double
    @Binding var lodTileSize: Double
    @Binding var lodPointsPerPixel: Double
    @Binding var isCullingEnabled: Bool
    @Binding var cullingBoundsScale: Double

    var body: some View {
        FittingScrollView {
            Divided {
                SystemInspectorSection(
                    duration: $duration,
                    particleCount: $particleCount,
                    seed: $seed
                )
                SpawnInspectorSection(
                    preset: $spawnPreset,
                    domain: $spawnDomain
                )
                ColorInspectorSection(color: $color)
                RenderingInspectorSection(
                    mode: $renderMode,
                    sizeSpace: $billboardSizeSpace,
                    facing: $billboardFacing,
                    width: $billboardWidth,
                    height: $billboardHeight,
                    rotation: $billboardRotation
                )
                if renderMode == .point {
                    PointLODInspectorSection(
                        isEnabled: $lodEnabled,
                        activation: $lodActivation,
                        maximum: $lodMaximum,
                        tileSize: $lodTileSize,
                        pointsPerPixel: $lodPointsPerPixel
                    )
                }
                CullingInspectorSection(
                    isEnabled: $isCullingEnabled,
                    scale: $cullingBoundsScale
                )
            }
            .frame(
                maxWidth: .infinity,
                alignment: .topLeading
            )
            .scenePadding()
            .padding(5)
        }
        .toggleStyle(.checkmark)
        .labeledContentStyle(.inspector)
        .focusable(false)
        .focusEffectDisabled(true)
        .clipShape(.rect(cornerRadius: 28))
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 28))
        .frame(maxWidth: 300)
        .animation(.snappy, value: spawnPreset)
        .animation(.snappy, value: renderMode)
        .animation(.snappy, value: lodEnabled)
        .animation(.snappy, value: cullingBoundsScale)
    }
}

#Preview {
    @Previewable @State var duration: Double = 20
    @Previewable @State var particleCount: Double = 200
    @Previewable @State var seed: Double = 0
    @Previewable @State var color = PixlParticles.Color.white
    @Previewable @State var spawnPreset = SpawnPreset.sphere
    @Previewable @State var spawnDomain = ParticleDocument.SpawnDomain.volume
    @Previewable @State var renderMode = ParticleRenderer.Mode.billboard
    @Previewable @State var billboardSizeSpace = BillboardRenderer.SizeSpace.world
    @Previewable @State var billboardFacing = BillboardRenderer.Facing.camera
    @Previewable @State var billboardWidth = 1.0
    @Previewable @State var billboardHeight = 2.0
    @Previewable @State var billboardRotation = 0.0
    @Previewable @State var lodEnabled = true
    @Previewable @State var lodActivation = 500_000.0
    @Previewable @State var lodMaximum = 1_000_000.0
    @Previewable @State var lodTileSize = 16.0
    @Previewable @State var lodPointsPerPixel = 1.0
    @Previewable @State var isCullingEnabled = true
    @Previewable @State var cullingBoundsScale = 500.0

    Inspector(
        duration: $duration,
        particleCount: $particleCount,
        seed: $seed,
        color: $color,
        spawnPreset: $spawnPreset,
        spawnDomain: $spawnDomain,
        renderMode: $renderMode,
        billboardSizeSpace: $billboardSizeSpace,
        billboardFacing: $billboardFacing,
        billboardWidth: $billboardWidth,
        billboardHeight: $billboardHeight,
        billboardRotation: $billboardRotation,
        lodEnabled: $lodEnabled,
        lodActivation: $lodActivation,
        lodMaximum: $lodMaximum,
        lodTileSize: $lodTileSize,
        lodPointsPerPixel: $lodPointsPerPixel,
        isCullingEnabled: $isCullingEnabled,
        cullingBoundsScale: $cullingBoundsScale
    )
    .fixedSize(horizontal: true, vertical: false)
    .scenePadding()
}

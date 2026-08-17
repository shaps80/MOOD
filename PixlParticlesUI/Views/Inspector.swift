import SwiftUI
import PixlParticles

struct Inspector: View {
    @Binding var duration: Double
    @Binding var particleCount: Double
    @Binding var seed: Double
    @Binding var spawnPreset: SpawnPreset
    @Binding var spawnDomain: ParticleDocument.SpawnDomain
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
                Section("System") {
                    LabeledContent("Duration") {
                        Field(
                            value: $duration,
                            step: 5,
                            range: 0 ... .infinity
                        )
                    }

                    LabeledContent("Particles") {
                        Field(
                            value: $particleCount,
                            step: particleCount > 100_000 ? 100_000 : 1_000,
                            range: 0 ... .infinity
                        )
                    }

                    LabeledContent("Seed") {
                        Field(value: $seed)
                    }
                }

                Section("Spawn") {
                    LabeledContent("Region") {
                        Picker("Domain", selection: $spawnPreset) {
                            ForEach(SpawnPreset.allCases, id: \.self) { preset in
                                Text(preset.title).tag(preset)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .tint(.primary)
                    }

                    if spawnPreset.supportedDomains.count > 1 {
                        LabeledContent("Spawn From") {
                            Picker("Spawn From", selection: $spawnDomain) {
                                ForEach(
                                    spawnPreset.supportedDomains,
                                    id: \.self
                                ) { domain in
                                    Text(domain.title).tag(domain)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .tint(.primary)
                        }
                    }
                }

                Section("Point LOD") {
                    Toggle("Enabled", isOn: $lodEnabled)

                    if lodEnabled {
                        LabeledContent("Activation") {
                            Field(value: $lodActivation, step: 100_000)
                        }

                        LabeledContent("Maximum") {
                            Field(value: $lodMaximum, step: 100_000)
                        }

                        LabeledContent("Tile Size") {
                            Field(value: $lodTileSize, step: 1)
                        }

                        LabeledContent("Points/Pixel") {
                            Field(value: $lodPointsPerPixel, step: 1)
                        }
                    }
                }

                Section("Culling") {
                    Toggle("Cull to Bounds", isOn: $isCullingEnabled)

                    LabeledContent("Bounds Scale") {
                        Field(
                            value: $cullingBoundsScale,
                            step: 25,
                            range: 1 ... 10_000
                        )
                    }
                }
            }
            .frame(
                maxWidth: .infinity,
                alignment: .topLeading
            )
            .scenePadding()
            .padding(5)
        }
        .labeledContentStyle(.inspector)
        .focusable(false)
        .focusEffectDisabled(true)
        .clipShape(.rect(cornerRadius: 28))
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 28))
        .frame(maxWidth: 250)
        .animation(.snappy, value: spawnPreset)
        .animation(.snappy, value: lodEnabled)
        .animation(.snappy, value: cullingBoundsScale)
    }
}

#Preview {
    @Previewable @State var duration: Double = 20
    @Previewable @State var particleCount: Double = 200
    @Previewable @State var seed: Double = 0
    @Previewable @State var spawnPreset = SpawnPreset.sphere
    @Previewable @State var spawnDomain = ParticleDocument.SpawnDomain.volume
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
        spawnPreset: $spawnPreset,
        spawnDomain: $spawnDomain,
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

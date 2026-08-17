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
    let areCullingBoundsVisible: Bool
    @Binding var areCullingBoundsEnabled: Bool
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
                            step: 1_000,
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

                if areCullingBoundsVisible || areCullingBoundsEnabled {
                    Section("Culling") {
                        Toggle("Cull to Bounds", isOn: $areCullingBoundsEnabled)

                        LabeledContent("Bounds Scale") {
                            Field(
                                value: $cullingBoundsScale,
                                step: 25,
                                range: 1 ... 10_000
                            )
                        }
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

struct Divided<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            Group(sections: content) { sections in
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        section.header
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Group(subviews: section.content) { subviews in
                            ForEach(subviews: subviews) { subview in
                                subview

                                if subview.id != subviews.last?.id {
                                    Divider()
                                }
                            }
                        }

                        if section.id != sections.last?.id {
                            Divider()
                        }
                    }
                    .padding(.horizontal, 2)
                    .clipped()
                }
            }
        }
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
    @Previewable @State var areCullingBoundsVisible = true
    @Previewable @State var areCullingBoundsEnabled = true
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
        areCullingBoundsVisible: areCullingBoundsVisible,
        areCullingBoundsEnabled: $areCullingBoundsEnabled,
        cullingBoundsScale: $cullingBoundsScale
    )
    .fixedSize(horizontal: true, vertical: false)
    .scenePadding()
}

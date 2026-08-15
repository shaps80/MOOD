import SwiftUI
import PixlParticles

struct Inspector: View {
    @Binding var duration: Double
    @Binding var particleCount: Double
    @Binding var seed: Double
    @Binding var spawnPreset: SpawnPreset

    var body: some View {
//        ScrollView {
            Divided {
                Section("System") {
                    LabeledContent("Duration") {
                        Field(value: $duration)
                    }

                    LabeledContent("Particles") {
                        Field(value: $particleCount)
                    }

                    LabeledContent("Seed") {
                        Field(value: $seed)
                    }

                    LabeledContent("Spawn") {
                        Picker("Spawn", selection: $spawnPreset) {
                            ForEach(SpawnPreset.allCases, id: \.self) { preset in
                                Text(preset.title).tag(preset)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .tint(.primary)
                    }
                }
            }
            .frame(
                maxWidth: .infinity,
                alignment: .topLeading
            )
            .scenePadding()
//        }
        .labeledContentStyle(.inspector)
        .focusable(false)
        .focusEffectDisabled(true)
        .clipShape(.rect(cornerRadius: 28))
        .glassEffect(.clear, in: .rect(cornerRadius: 28))
        .frame(maxWidth: 250)
    }
}

struct Divided<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            Group(sections: content) { sections in
                ForEach(sections) { section in
                    VStack(alignment: .leading) {
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
                    }
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

    Inspector(
        duration: $duration,
        particleCount: $particleCount,
        seed: $seed,
        spawnPreset: $spawnPreset
    )
    .fixedSize(horizontal: true, vertical: false)
    .scenePadding()
}

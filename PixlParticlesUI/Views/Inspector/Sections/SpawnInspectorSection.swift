import SwiftUI

struct SpawnInspectorSection: View {
    @Binding var preset: SpawnPreset
    @Binding var domain: ParticleDocument.SpawnDomain

    var body: some View {
        Section("Spawn") {
            LabeledContent("Region") {
                Picker("Domain", selection: $preset) {
                    ForEach(SpawnPreset.allCases, id: \.self) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(.primary)
            }

            if preset.supportedDomains.count > 1 {
                LabeledContent("Spawn From") {
                    Picker("Spawn From", selection: $domain) {
                        ForEach(preset.supportedDomains, id: \.self) { domain in
                            Text(domain.title).tag(domain)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(.primary)
                }
            }
        }
    }
}

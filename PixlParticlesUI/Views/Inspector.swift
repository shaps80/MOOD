import SwiftUI
import PixlParticles

struct Inspector: View {
    @State private var value: Double = 20
    var body: some View {
        ScrollView {
            Divided {
                Section("Test") {
                    // duration, particles (count), etc...
                    LabeledContent("Duration") {
                        Field(value: $value)
                    }
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .scenePadding()
        }
        .focusable(false)
        .focusEffectDisabled(true)
        .clipShape(.rect(cornerRadius: 28))
        .glassEffect(.clear.tint(.black.opacity(0.3)), in: .rect(cornerRadius: 28))
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
    Inspector()
        .fixedSize(horizontal: true, vertical: false)
        .scenePadding()
}

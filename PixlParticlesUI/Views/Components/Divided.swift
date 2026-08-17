import SwiftUI

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
                    .padding(2)
                    .clipped()
                }
            }
        }
    }
}

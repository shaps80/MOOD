import SwiftUI

struct CheckmarkToggleStyle: ToggleStyle {
    @Environment(\.labelsVisibility) var visibility

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                if visibility != .hidden {
                    configuration.label
                    Spacer(minLength: 0)
                }

                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
                    .fontWeight(configuration.isOn ? .heavy : .regular)
                    .animation(nil, value: configuration.isOn)
            }
        }
        .buttonStyle(.none)
    }
}

extension ToggleStyle where Self == CheckmarkToggleStyle {
    static var checkmark: Self { .init() }
}

struct NoButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

extension ButtonStyle where Self == NoButtonStyle {
    static var none: Self { .init() }
}

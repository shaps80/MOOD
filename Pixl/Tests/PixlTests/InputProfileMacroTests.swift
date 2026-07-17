import Pixl
import Testing

@InputProfile
private struct TestInputProfile {
    @Binding(
        .key(.a),
        .key(.arrowLeft),
        .button(.left),
        .axis(.leftStickX, direction: .negative)
    )
    let left: Input
}

@Suite("Input profile macro")
struct InputProfileMacroTests {
    @Test("Generates concrete input storage and remapping")
    func generatedProfile() {
        let profile = TestInputProfile()

        #expect(profile.left.value == 0)
        profile.setBindings([.key(.j)], for: profile.left)
    }
}

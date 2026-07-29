import PixlGraphics
import Testing
@testable import PixlUI

@Suite struct IdentityTests {
    @Test func explicitIdentityPreservesStateWhileUnchanged() throws {
        let probe = Probe()
        let scene = Scene(IdentifiedCounter(probe: probe))

        try prepare(scene)
        probe.count.wrappedValue = 42
        try prepare(scene)

        #expect(probe.values == [0, 42])
    }

    @Test func changingExplicitIdentityCreatesNewState() throws {
        let probe = Probe()
        let scene = Scene(IdentifiedCounter(probe: probe))

        try prepare(scene)
        probe.count.wrappedValue = 42
        probe.id.wrappedValue = 2
        try prepare(scene)

        #expect(probe.values == [0, 0])
    }

    @Test func equalExplicitIDsRemainScopedByStructuralIdentity() throws {
        let first = Probe()
        let second = Probe()
        let scene = Scene(PairedCounters(first: first, second: second))

        try prepare(scene)
        first.count.wrappedValue = 1
        second.count.wrappedValue = 2
        try prepare(scene)

        #expect(first.values == [0, 1])
        #expect(second.values == [0, 2])
    }

    private func prepare<Content: View>(_ scene: Scene<Content>) throws {
        _ = try scene.prepare(
            size: .init(width: 100, height: 100),
            displayScale: 1,
            resolveImage: { _ in fatalError("Unexpected image") }
        )
    }
}

private final class Probe {
    nonisolated(unsafe) var id: Binding<Int>!
    nonisolated(unsafe) var count: Binding<Int>!
    nonisolated(unsafe) var values: [Int] = []
}

private struct IdentifiedCounter: View {
    @State private var id = 1
    let probe: Probe

    var body: some View {
        probe.id = $id
        return Counter(probe: probe)
            .id(id)
    }
}

private struct PairedCounters: View {
    let first: Probe
    let second: Probe

    var body: some View {
        VStack {
            Counter(probe: first).id(1)
            Counter(probe: second).id(1)
        }
    }
}

private struct Counter: View {
    @State private var count = 0
    let probe: Probe

    var body: some View {
        probe.count = $count
        probe.values.append(count)
        return Text("\(count)")
    }
}

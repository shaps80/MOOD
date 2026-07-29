import PixlGraphics
import Testing
@testable import PixlUI

@Suite struct ForEachTests {
    @Test func identifiableDataPreservesStateWhenReordered() throws {
        let probe = ForEachProbe()
        let scene = Scene(IdentifiableRows(probe: probe))

        try prepare(scene)
        probe.counts[1]!.wrappedValue = 10
        probe.counts[2]!.wrappedValue = 20
        probe.items.wrappedValue = [.init(id: 2), .init(id: 1)]
        try prepare(scene)

        #expect(probe.values[1] == [0, 10])
        #expect(probe.values[2] == [0, 20])
    }

    @Test func insertionDoesNotShiftExistingState() throws {
        let probe = ForEachProbe()
        let scene = Scene(IdentifiableRows(probe: probe))

        try prepare(scene)
        probe.counts[2]!.wrappedValue = 20
        probe.items.wrappedValue = [.init(id: 0), .init(id: 1), .init(id: 2)]
        try prepare(scene)

        #expect(probe.values[0] == [0])
        #expect(probe.values[1] == [0, 0])
        #expect(probe.values[2] == [0, 20])
    }

    @Test func removalDoesNotResetRemainingState() throws {
        let probe = ForEachProbe()
        let scene = Scene(IdentifiableRows(probe: probe))

        try prepare(scene)
        probe.counts[2]!.wrappedValue = 20
        probe.items.wrappedValue = [.init(id: 2)]
        try prepare(scene)

        #expect(probe.values[1] == [0])
        #expect(probe.values[2] == [0, 20])
    }

    @Test func replacingIDCreatesFreshState() throws {
        let probe = ForEachProbe()
        let scene = Scene(IdentifiableRows(probe: probe))

        try prepare(scene)
        probe.counts[1]!.wrappedValue = 10
        probe.items.wrappedValue = [.init(id: 3), .init(id: 2)]
        try prepare(scene)

        #expect(probe.values[1] == [0])
        #expect(probe.values[2] == [0, 0])
        #expect(probe.values[3] == [0])
    }

    @Test func explicitIDKeyPathPreservesState() throws {
        let probe = KeyedProbe()
        let scene = Scene(KeyedRows(probe: probe))

        try prepare(scene)
        probe.counts["one"]!.wrappedValue = 10
        probe.items.wrappedValue.reverse()
        try prepare(scene)

        #expect(probe.values["one"] == [0, 10])
        #expect(probe.values["two"] == [0, 0])
    }

    private func prepare<Content: View>(_ scene: Scene<Content>) throws {
        _ = try scene.prepare(
            size: .init(width: 100, height: 100),
            displayScale: 1,
            resolveImage: { _ in fatalError("Unexpected image") }
        )
    }
}

private struct Item: Identifiable {
    let id: Int
}

private final class ForEachProbe {
    nonisolated(unsafe) var items: Binding<[Item]>!
    nonisolated(unsafe) var counts: [Int: Binding<Int>] = [:]
    nonisolated(unsafe) var values: [Int: [Int]] = [:]
}

private struct IdentifiableRows: View {
    @State private var items = [Item(id: 1), Item(id: 2)]
    let probe: ForEachProbe

    var body: some View {
        probe.items = $items
        return VStack {
            ForEach(items) { item in
                IdentifiableRow(id: item.id, probe: probe)
            }
        }
    }
}

private struct IdentifiableRow: View {
    @State private var count = 0
    let id: Int
    let probe: ForEachProbe

    var body: some View {
        probe.counts[id] = $count
        probe.values[id, default: []].append(count)
        return Text("\(count)")
    }
}

private struct KeyedItem {
    let key: String
}

private final class KeyedProbe {
    nonisolated(unsafe) var items: Binding<[KeyedItem]>!
    nonisolated(unsafe) var counts: [String: Binding<Int>] = [:]
    nonisolated(unsafe) var values: [String: [Int]] = [:]
}

private struct KeyedRows: View {
    @State private var items = [KeyedItem(key: "one"), KeyedItem(key: "two")]
    let probe: KeyedProbe

    var body: some View {
        probe.items = $items
        return VStack {
            ForEach(items, id: \.key) { item in
                KeyedRow(id: item.key, probe: probe)
            }
        }
    }
}

private struct KeyedRow: View {
    @State private var count = 0
    let id: String
    let probe: KeyedProbe

    var body: some View {
        probe.counts[id] = $count
        probe.values[id, default: []].append(count)
        return Text("\(count)")
    }
}

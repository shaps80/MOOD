@testable import PixlMemory
import Testing

@Layout("Policy child")
private struct PolicyChild {
    @Region var inherited: UInt8
    @Region(policy: .lazy) var lazyOverride: UInt8

    static func make(_ layout: inout Layout) {
        layout.reserve(\.inherited, count: 1)
        layout.reserve(\.lazyOverride, count: 1)
    }
}

@Layout("Policy parent", policy: .lazy)
private struct PolicyParent {
    @Region var inherited: UInt8
    @Region(policy: .eager) var eagerOverride: UInt8

    static func make(_ layout: inout Layout) {
        layout.reserve(\.inherited, count: 1)
        layout.reserve(\.eagerOverride, count: 1)
        layout.reserve(PolicyChild.self)
    }
}

@Test
private func preparationPolicyResolvesOverrideThenLayoutThenParentThenEager() throws {
    let persistent = try LayoutCompiler.compile(EmptyPersistent.self)
    let parentRecord = try LayoutCompiler.compile(PolicyParent.self)
    let arena = ArenaStorage(
        name: nil,
        logging: .disabled,
        persistent: persistent,
        layouts: [parentRecord]
    )

    let parent = arena.acquire(
        PolicyParent.self,
        policy: nil,
        source: SourceLocation()
    )
    #expect(parent.effectivePolicy == .lazy)
    #expect(parent.preparationPolicy(for: parent.regions["inherited"]!) == .lazy)
    #expect(parent.preparationPolicy(for: parent.regions["eagerOverride"]!) == .eager)

    let inheritedChild = parent.acquire(
        PolicyChild.self,
        policy: nil,
        source: SourceLocation()
    )
    #expect(inheritedChild.effectivePolicy == .lazy)
    #expect(inheritedChild.preparationPolicy(for: inheritedChild.regions["inherited"]!) == .lazy)
    #expect(inheritedChild.preparationPolicy(for: inheritedChild.regions["lazyOverride"]!) == .lazy)
    inheritedChild.release(cascading: true)
    parent.release(cascading: true)

    let overriddenParent = arena.acquire(
        PolicyParent.self,
        policy: .eager,
        source: SourceLocation()
    )
    #expect(overriddenParent.effectivePolicy == .eager)
    #expect(overriddenParent.preparationPolicy(for: overriddenParent.regions["inherited"]!) == .eager)

    let overriddenChild = overriddenParent.acquire(
        PolicyChild.self,
        policy: .eager,
        source: SourceLocation()
    )
    #expect(overriddenChild.effectivePolicy == .eager)
    #expect(overriddenChild.preparationPolicy(for: overriddenChild.regions["inherited"]!) == .eager)
    #expect(overriddenChild.preparationPolicy(for: overriddenChild.regions["lazyOverride"]!) == .lazy)
    overriddenParent.release(cascading: true)
}

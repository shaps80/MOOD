import Swift

@attached(accessor)
public macro Region(
    _ kind: RegionKind = .indexedBuffer,
    policy: PreparationPolicy? = nil
) = #externalMacro(
    module: "PixlMemoryMacros",
    type: "RegionMacro"
)

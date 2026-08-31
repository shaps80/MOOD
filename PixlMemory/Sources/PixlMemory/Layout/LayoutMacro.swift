import Swift

@attached(
    member,
    names: named(Layout), named(memoryLayoutName), named(preparationPolicy),
    named(memoryRegionDeclarations), named(make)
)
@attached(
    extension,
    conformances: MemoryLayoutDefinition
)
public macro Layout(
    _ name: String,
    policy: PreparationPolicy? = nil
) = #externalMacro(
    module: "PixlMemoryMacros",
    type: "LayoutMacro"
)

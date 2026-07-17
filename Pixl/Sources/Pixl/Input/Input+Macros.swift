/// Generates the backing storage, initialization, binding, and remapping
/// methods for a game-defined input profile.
@attached(
    member,
    names: named(storage), named(init), named(bind), named(setBindings)
)
public macro InputProfile() = #externalMacro(
    module: "PixlMacros",
    type: "InputProfileMacro"
)

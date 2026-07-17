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

/// Declares the default physical bindings for one input in an input profile.
@attached(peer)
public macro Binding(
    _ bindings: Input.Binding...
) = #externalMacro(
    module: "PixlMacros",
    type: "BindingMacro"
)

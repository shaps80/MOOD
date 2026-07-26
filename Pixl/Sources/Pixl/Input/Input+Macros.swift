/// Generates backing storage, initialization, binding, and remapping methods
/// for a game-defined profile containing `@InputMap` properties.
@attached(
    member,
    names: named(storage), named(init), named(bind), named(setBindings)
)
public macro InputProfile() = #externalMacro(
    module: "PixlMacros",
    type: "InputProfileMacro"
)

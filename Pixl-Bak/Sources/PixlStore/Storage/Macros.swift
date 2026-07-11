@attached(member, names: arbitrary)
@attached(memberAttribute)
@attached(peer, names: suffixed(Schema), suffixed(Group))
@attached(extension, conformances: FrameEntity, _PixlEntityType, PixlStoreSchemaType, names: named(_PixlSchema), named(_PixlGroup), named(_pixlCreateComponents), named(_pixlDestroyComponents), named(pixlSchemaMetadata))
public macro Entity() = #externalMacro(
    module: "PixlStoreMacros",
    type: "EntityMacro"
)

@attached(member, names: arbitrary)
@attached(memberAttribute)
@attached(peer, names: suffixed(Schema), suffixed(Group))
@attached(extension, conformances: FrameComponent, _PixlComponentType, PixlStoreSchemaType, names: named(_PixlSchema), named(_PixlGroup), named(pixlSchemaMetadata))
public macro Component() = #externalMacro(
    module: "PixlStoreMacros",
    type: "ComponentMacro"
)

@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: prefixed(`_`))
public macro _PixlStored(
    schema: String,
    group: String,
    column: String,
    owner: String
) = #externalMacro(
    module: "PixlStoreMacros",
    type: "StoredPropertyMacro"
)

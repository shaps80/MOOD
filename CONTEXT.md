# Pixl Architecture and Vocabulary

PixlPlatform is Pixl's lowest platform-agnostic API boundary. It defines the minimum portable building blocks for graphics, input, audio, assets, and runtime integration, with concrete platform targets providing their native implementations. Higher-level conveniences and game-facing abstractions belong above it so every platform benefits from the same shared functionality.

## Package Responsibilities

`Pixl`
: Pixl's primary game-facing entry point. Its purpose is to make game development intuitive, fun, and easy through obvious Swift value construction, useful defaults, common rendering and runtime conveniences, and direct explicit control where that improves the game-authoring experience. A game should normally begin with `import Pixl` and discover its common path without understanding engine resource resolution or platform APIs.

Game-facing value initializers require only the minimum structurally necessary inputs and expose remaining stored properties as parameters whenever those properties have reasonable defaults. Such parameters retain their defaults so ordinary construction stays concise while one-off overrides remain direct. Properties are mutable unless post-initialization mutation would violate the value's invariants; callers may always construct simply and then mutate ordinary state.

`PixlFoundation`
: Pixl's platform-independent engine infrastructure and lower-level game-engine mechanics required for games to function. It owns deliberate direct engine abstractions, engine descriptors, resource resolution and cache machinery, render keys and records, and other mechanisms used beneath Pixl conveniences. It may expose low-level public APIs for games that intentionally import it, and use `package` access for implementation shared by sibling targets in the Pixl package.

`PixlPlatform`
: Pixl's minimum platform-agnostic input/output boundary over platform APIs. It defines portable contracts and raw explicit resource operations; concrete adapters implement those contracts with Metal, WebGPU, native audio, windows, devices, files, and other platform facilities. It does not own engine convenience, material interpretation, batching policy, or engine resource deduplication.

The domain libraries remain independent horizontal streams:

```text
PixlUI -> PixlInput + PixlGraphics
Pixl2D -> PixlGraphics + PixlMath
Pixl3D -> PixlGraphics
future PixlPhysics -> PixlMath
```

Domain targets add PixlMath directly when their implementation needs its shared operations; they do not acquire unrelated dependencies merely to anticipate future work.

Portable Pixl targets must not import or rely on APIs carrying operating-system deployment requirements, even when exposed from a Swift-named module. Such availability is evidence of a platform-specific implementation and places the API outside the portable layers. Portable third-party dependencies must support every target platform directly; concrete platform adapters remain the only place for OS-bound APIs.

They define convenient, efficient domain values and algorithms without depending on engine execution infrastructure. `Pixl` is the orchestrator and bridge: it consumes domain values, lowers them into optimized `PixlFoundation` representations and lifetimes, then `PixlFoundation` resolves those through `PixlPlatform`. Domain targets do not depend on `PixlFoundation`; package access does not bypass target dependencies.

Spatial, graphical, and normalized input values use single-precision `Float` storage throughout the portable layers. This keeps public values aligned with GPU representation, reduces retained world storage and improves cache density without conversion at render submission. Time, accumulated durations, performance measurements, and other long-running temporal calculations remain `Double`. Very large worlds preserve precision through chunk-local coordinates or origin rebasing rather than carrying double-precision positions into a single-precision GPU pipeline.

Pixl deliberately depends on PixlGraphics, Pixl2D, and Pixl3D even before every bridge exists. These are orchestration edges: Pixl is where domain values meet Foundation execution mechanisms. PixlGraphics is also deliberately re-exported as Pixl's common, dimension-independent graphics vocabulary. Pixl2D and Pixl3D are not re-exported; the Game needs only the Pixl product while explicitly importing whichever dimensional domain modules its source uses.

```text
domain values -> Pixl bridge -> PixlFoundation -> PixlPlatform -> native APIs
```

A type belongs in `PixlFoundation` only when it is engine-specific rather than platform I/O, provides infrastructure beneath Pixl conveniences or deliberate direct engine control, excludes gameplay and scene ownership, and preserves this execution direction. `PixlFoundation` is not a home for miscellaneous utilities, convenience extracted merely for file sharing, platform/backend concepts, game-owned state, entities, scenes, or abstractions without a concrete engine consumer. It is predominantly package-scoped initially, but public direct APIs are valid when a concrete need justifies them.

`Pixl` re-exports only PixlGraphics because its stable, common vocabulary is expected in any Pixl game. This is a deliberate exception, not permission for broad umbrella exports: PixlPlatform, PixlFoundation, Pixl2D, and Pixl3D remain explicit imports for direct use. Pixl selectively exposes required PixlPlatform identities through zero-cost public type aliases where the underlying type already has the correct semantics. Resource-resolution methods remain internal or package-scoped even when their descriptor types are public. Every public addition to PixlGraphics therefore affects Pixl's visible API and must remain genuinely dimension-independent graphics vocabulary rather than execution infrastructure or dimensional convenience.

`PixlGraphics`
: Dimension-independent graphics vocabulary and algorithms shared by 2D and 3D, such as `Color`, `Angle`, image representations, decoding, and logical texture assets. It is a domain library, not engine execution infrastructure. `PixlGraphics.Color` is the single public semantic colour value: a nominal, SIMD-backed RGBA struct shared by graphics and UI. PixlUI depends on PixlGraphics and extends that same type with `View` and `ShapeStyle` behaviour rather than defining another colour. Hot render records lower colour explicitly to the struct's `SIMD4<Float>` storage. `PixlPlatform.Color` remains a raw `SIMD4<Float>` alias at the platform command boundary; Pixl performs the zero-allocation semantic-to-raw lowering when constructing clear actions and execution records.

`PixlInput`
: Platform-independent semantic input identity, value, and transition phase shared by games and PixlUI. It contains no keyboard, gamepad, mouse, or platform device vocabulary. Pixl owns physical `Input.Binding`, profile compilation, device polling, and `Input.Map`; PixlUI consumes already-resolved semantic `Input` values through modifiers such as `onInput`. Each semantic input retains its originating profile so Pixl can automatically and idempotently register profiles consumed by a compiled UI Scene without a separate view annotation.

`Pixl2D`
: Complete game-facing two-dimensional domain values and operations, including sprite descriptions, sprite materials, regions, sheets, animation, layers, geometry, transforms, and cameras. These remain ordinary efficient values rather than execution objects. `Triangle` and `Quad` contain points and per-vertex colours; they do not create buffers, retain devices, throw during construction, or record draws. `OrthographicCamera` computes projection transforms and visible world bounds from a `Vec2` viewport size or a positive aspect ratio and has no render-target knowledge. Pixl owns the convenience bridge that extracts a `RenderTarget` size and calls the pure camera API. Pixl2D depends on PixlGraphics and PixlMath, not PixlPlatform or PixlFoundation.

PixlPlatform convenience may normalize awkward native APIs into coherent Swift values such as `GamePhase`, `Keyboard`, or direct encoder commands. The abstraction must remain at the platform capability level and must not add engine policy. Portable normalization must introduce the minimum measurable overhead required by the boundary; ergonomics never justify avoidable hot-path allocation, copying, synchronization, dynamic dispatch, hashing, or state translation.

PixlPlatform is state-minimal and ownership-explicit rather than literally stateless. It owns native state required by windows, devices, queues, input snapshots, resources, callbacks, and frame recording, but avoids implicit caches, undocumented retention, automatic batching or deduplication, engine-level lifecycle policy, and hidden mutation. Higher layers own those concerns.

Its GPU interface follows Metal's direct encoder/resource-slot model, with modern DirectX used as a second alignment reference. WebGPU and Vulkan must implement the same capabilities, but their bind groups, descriptor sets, layout declarations, and pipeline variants are adapter machinery unless a future cross-platform requirement proves otherwise.

This is not a legacy OpenGL/WebGL state-machine abstraction. The platform boundary is dimension-agnostic and camera-agnostic; 2D, 3D, and camera meaning belongs in higher layers.

## Platform Mapping

| PixlPlatform | Metal | DirectX 12 | WebGPU adapter | Vulkan adapter |
| --- | --- | --- | --- | --- |
| `Platform` | runtime + `MTKView` | runtime + swapchain | runtime + canvas context | runtime + swapchain |
| `Device` | `MTLDevice` | `ID3D12Device` | `GPUDevice` | `VkDevice` |
| `Queue` | `MTLCommandQueue` | `ID3D12CommandQueue` | `GPUQueue` | `VkQueue` |
| `Frame` | recorded command-buffer input | recorded command-list input | command-encoder input | command-buffer input |
| `Buffer` | `MTLBuffer` | `ID3D12Resource` | `GPUBuffer` | `VkBuffer` |
| `Texture` | `MTLTexture` | `ID3D12Resource` | `GPUTexture` | `VkImage` / `VkImageView` |
| `Sampler` | `MTLSamplerState` | sampler descriptor | `GPUSampler` | `VkSampler` |
| `RenderPipeline` | `MTLRenderPipelineState` | `ID3D12PipelineState` | `GPURenderPipeline` variant | `VkPipeline` variant |
| `VertexLayout` | `MTLVertexDescriptor` | `D3D12_INPUT_LAYOUT_DESC` | `GPUVertexBufferLayout` | `VkVertexInput*` descriptions |
| `RenderPassDescriptor` | `MTLRenderPassDescriptor` | RTV/DSV pass configuration | `GPURenderPassDescriptor` | dynamic-rendering/pass configuration |
| `RenderPassEncoder` | `MTLRenderCommandEncoder` | graphics command list methods | `GPURenderPassEncoder` | `vkCmd*` recording |
| `setRenderPipeline` | `setRenderPipelineState` | `SetPipelineState` | `setPipeline` | `vkCmdBindPipeline` |
| `setVertexBuffer` | `setVertexBuffer` | root/descriptor or vertex-buffer binding | vertex buffer or internal bind group | vertex buffer or internal descriptor set |
| `setFragmentTexture` | `setFragmentTexture` | descriptor table/root binding | internal bind group | internal descriptor set |
| `setFragmentSampler` | `setFragmentSamplerState` | sampler descriptor table | internal bind group | internal descriptor set |
| `drawPrimitives` | `drawPrimitives` | `DrawInstanced` | `draw` | `vkCmdDraw` |
| `drawIndexedPrimitives` | `drawIndexedPrimitives` | `DrawIndexedInstanced` | `setIndexBuffer` + `drawIndexed` | `vkCmdBindIndexBuffer` + `vkCmdDrawIndexed` |
| `RenderTarget` | texture + mip/slice | resource/view | `GPUTextureView` | `VkImageView` |

WebGPU/Vulkan may require adapter-owned grouping or pipeline variants to implement a direct Pixl encoder command. That does not change the public vocabulary.

## Core Objects

`Device`
: Logical GPU access. Creates queues and resources. Pooled resources are explicitly destroyed through the same device.

`Queue`
: Submission lane for recorded `Frame` work.

`Platform`
: Frame-presentation seam. Exposes the device, acquires a frame-scoped `Drawable`, and presents a recorded `Frame`.

`Platform.displayScale`
: Current presentation-pixel density expressed as pixels per logical screen-space point. Concrete window/canvas adapters source it from native presentation state; adapters without density-aware presentation default to `1`. `GameContext` exposes the value to games, and higher layers use it for logical screen-space layout and pixel alignment.

`Frame`
: Reusable, fixed-capacity, allocation-free recording storage for ordered passes and primitive encoder commands. Public callers cannot append internal pass/command values directly.

## Game Lifecycle and Time

`GamePhase`
: Coarse platform lifecycle: `background`, `active`, or `inactive`. Loading and preparation remain game-owned state. Phase transitions are delivered once through `Game.didEnter(_:context:)`.

`GameContext`
: Stable runtime-owned reference supplied during game initialization and as the final argument to every lifecycle, update, and render callback. It exposes the platform, drawable format, audio, assets, and mutable time scale; it does not expose all startup `RenderSettings`. `Game.didEnter`, `fixedUpdate`, and `update` mutate the game value directly, while `render` is read-only.

`GameContext.timeScale`
: Nonnegative simulation-time multiplier. `0` suppresses fixed updates while presentation updates and rendering continue. Audio and unscaled time remain independent. Changes made by a callback affect the next presentation schedule, allowing `UpdateTime.unscaledDelta` to drive pause and slow-motion ramps.

`FixedTime.delta`
: Fixed simulation step after game time scaling determines whether a tick occurs.

`UpdateTime.delta`
: Clamped presentation delta multiplied by `GameContext.timeScale`.

`UpdateTime.unscaledDelta`
: The same clamped presentation delta before `GameContext.timeScale`. Lifecycle fades and other work that must continue while simulation is paused use this value.

Pixl has no dependency on or re-export of `PixlConcurrency`; games may depend on that standalone package directly when they need explicit lanes.

## Keyboard Input

`Keyboard`
: Platform-owned physical keyboard state exposed through `Platform` and `GameContext`. `contains(_:)` reads current down-state in constant time. `events` is the ordered, contiguous transition batch published for the current presentation frame; `key(_:phase:)` and `contains(_:phase:)` use constant-time per-key/per-phase lookup.

`Key`
: Portable physical key position, independent of produced character and active keyboard layout. macOS translates `NSEvent.keyCode`; the browser translates `KeyboardEvent.code`.

`Key.Event`
: One `.down` or `.up` transition with the complete `Key.Modifiers` snapshot. The first down has `isRepeat == false`; native auto-repeat downs have `isRepeat == true` and coalesce to at most one event per key per frame. Current held state remains separate from event phase.

Keyboard event storage is runtime-owned, fixed-capacity, contiguous, and double-buffered. Native callbacks append into pending storage; presentation swaps it into the published frame without copying or allocating. At most one event per key and phase is retained each frame, so capacity derives from the closed `Key` vocabulary rather than game settings. Focus loss synthesizes `.up` for every down key before clearing state. `Keyboard.isFocused` reports keyboard focus.

## Gamepad Input

`Gamepads`
: Platform-owned collection of connected controllers, exposed through `Platform` and `GameContext`. Slot storage grows only when a controller with a new index connects; connection/disconnection are cold paths. Player indices remain stable across disconnection and reconnection, while frame polling and per-controller state remain allocation-free.

`Gamepad`
: One physical controller with normalized button values, y-up left/right stick vectors, connection identity, and fixed-capacity contiguous per-frame transitions. Concrete adapters poll retained native controller state once per presentation; macOS connection notifications avoid allocating a controller list in the frame loop, while the browser consumes only its standard gamepad mapping.

`Gamepad.Button`
: Physical control location rather than vendor label. Face buttons are `.south`, `.east`, `.west`, and `.north`; D-pad buttons are `.up`, `.down`, `.left`, and `.right`. Shoulder, trigger, stick-press, menu, and options controls retain those portable physical names. Triggers always expose normalized `0...1` values, naturally representing either analogue hardware or digital `0`/`1` controls. Adaptive-trigger resistance, Home/system buttons, and haptics are not part of the current contract.

`Gamepad.Button.Event`
: A coalesced `.down` or `.up` transition carrying its normalized value. Current pressed state and continuous analogue values remain independently queryable in constant time. Stick displacement does not produce button events.

## Resource Ownership

`ResourceID`
: Package-visible 64-bit generational handle: 32-bit direct slot index plus 32-bit generation. Generation zero is reserved. Stale handles fail lookup after destruction/reuse. A phantom generic tag was measured and rejected after roughly 55% release lookup regression across the package seam.

`ResourcePool`
: Package-level fixed-capacity native-resource storage. It uses contiguous manually managed slots, O(1) lookup/removal, generation validation, and an intrusive free list. It allocates only at initialization and contains no internal synchronization.

`Buffer`, `Texture`, `Sampler`, `RenderPipeline`
: Copyable opaque handles plus deliberate public metadata where applicable. Creation inserts a native resource into its backend pool. `Device.destroy` invalidates the handle immediately and returns the slot for reuse. Copies of a destroyed handle are stale. Backends remain responsible for deferring native reclamation when already-submitted GPU work still references that resource.

`Drawable`
: Noncopyable frame-scoped presentable texture. Presentation consumes it. Its transient texture is platform-owned and must not be explicitly destroyed by game code.

Release `PixlPlatform` builds use `-enable-cmo-everything`, allowing concrete package adapters to specialize hot package-private generic code such as `ResourcePool<Value>`.

## Buffers and Textures

`BufferDescriptor`
: Describes an entire buffer allocation: byte size, allowed usage roles, and memory intent.

`BufferMemory`
: Explicit allocation intent: `.gpuOnly`, `.cpuVisible`, or `.gpuToCPU`. It is intent, not a promise of identical physical memory on every backend.

`BufferUsage`
: Allowed roles such as vertex, index, uniform, storage, copy source, and copy destination.

`TextureDescriptor`
: Describes an entire texture allocation. Dimension/type, mip, cube, and richer array semantics remain an explicit future design gate.

PixlPlatform textures are currently GPU-owned resources with no direct CPU mapping API. Metal therefore allocates them with private storage; uploads, hot reload, and future readback use backend-owned staging transfers rather than shared final textures. Do not expose backend memory-placement vocabulary unless a portable CPU-access operation requires it.

`Device.makeTexture(copying:descriptor:bytesPerRow:)`
: Creates a texture with initial owned pixel bytes. Metal stages rows into an aligned transfer buffer and blits into private texture storage before publishing the handle.

`TextureWriter`
: Optional backend-owned asynchronous access to one existing texture. It supports event-driven same-size content replacement without changing the public texture handle or touching frame recording. Metal orders writes and rendering through the same command queue. Backends that do not support live texture writes return no writer.

`SamplerDescriptor`
: Portable filtering and address-mode state. Samplers are pooled opaque resources, independent of textures.

`RenderTarget`
: Texture view shape selecting a texture, mip level, and array layer.

`RenderPassEncoder.colorFormat`
: Constant-time read-only metadata derived from the pass's recorded colour attachment. Higher engine layers use the actual pass format for pipeline compatibility rather than duplicating target state in queue construction or encode arguments.

## Logical Assets and Loading

`PixlGraphics.TextureAsset`
: A lightweight, platform-independent value identifying one logical texture asset and exposing useful graphics metadata such as pixel size. It contains no `PixlPlatform.Texture`, device, native resource, or execution policy. Its identity is opaque to games; the concrete handle encoding remains an implementation detail. The same logical identity survives backing-resource replacement during hot reload.

`PixlFoundation`
: Owns the runtime mapping from logical texture identity to resolved platform resources, plus deduplication, lifetime, invalidation, and replacement. The game runtime owns this infrastructure and exposes it through `GameContext`; games retain only lightweight asset values.

`Assets.load(texture:)`
: Pixl's game-facing orchestration path. Pixl reads bytes through the platform capability, decodes image data through PixlGraphics, registers or resolves execution storage through PixlFoundation, then returns the corresponding `PixlGraphics.TextureAsset`. A function's owning module need not own its return type. Required startup assets throw `AssetError` rather than becoming optional values with logged errors.

Pixl may add public convenience initializers or methods to domain types it imports. Package-scoped domain initializers can accept opaque primitive identity and metadata, allowing Pixl to construct complete game-facing values without a dependency from PixlGraphics or Pixl2D back to PixlFoundation. Public extension signatures must not expose package-only Foundation types. This bridge pattern preserves concrete static types: it requires no `Any`, existential, or generic facade.

## 2D Authoring and Render Intent

`TextureRegion`
: Pixl2D-owned rectangular pixel selection within a `PixlGraphics.TextureAsset`. Its top-left image-space source rectangle lowers to normalized texture-coordinate offset and scale. Sprite sheets, atlases, animations, tiles, and future glyph atlases can share this primitive without adding region vocabulary to PixlPlatform or PixlFoundation.

`SpriteSheet`
: Pixl2D-owned regular row-major grid deriving equally sized `TextureRegion` values from one texture. Horizontal and vertical `RangeExpression` subscripts select occupied cells of packed animation strips; row-only and column-only subscripts select a complete strip. Irregular named atlas metadata remains a later Pixl2D layer over the same region primitive.

`SpriteAnimation` / `SpriteAnimation.Timeline`
: Pixl2D-owned immutable uniformly timed region sequence and mutable playback position. Games own timelines and animation switching; sprites remain render state rather than update-owning objects. The generic `Timer` remains a clamped one-shot progress value rather than gaining animation looping or frame-selection semantics.

`RenderLayer`
: Pixl2D-owned unsigned integer-backed game-defined sprite ordering. Pixl defines no named layers or configured maximum. Lower values render first. Foundation discovers the sparse set of active values and compresses them into contiguous internal bins bounded by queue capacity, so game-facing values do not imply direct array indexing or one allocation per possible layer. Layers are CPU draw-order semantics, not GPU depth.

`Sprite`
: Pixl2D's obvious construction and discovery point for sprite rendering. It is an ordinary game-owned Swift value containing its region, nested `Sprite.Material`, layer, local order, and presentation state. Games mutate those properties directly during update and explicitly submit the latest value during rendering. They do not register ordinary sprites, receive internal material keys, or return mutated values through `GameContext`.

Pixl's asset-loading convenience constructs a sprite with its default state; game code changes properties such as `sprite.layer` or `sprite.order` rather than passing them into `Sprite(named:context:)`. The convenience accepts cold-load alpha processing because that choice changes the uploaded texture representation: `.premultiplied` is the default and multiplies decoded RGB by alpha before upload, while `.passthrough` preserves decoded PNG RGBA. The resulting `TextureAsset` records that processing so normal sprite composition automatically selects a matching pipeline; alpha processing is neither sampler state nor mutable sprite material state. Pixl2D's designated initializer requires only a region and exposes every property with a reasonable default. `order` is local to its layer; submission ordinal provides the stable final tie-break.

`Sprite.Material`
: Pixl2D's value-semantic description of how a sprite's primary image is sampled and composed. The primary `TextureAsset` remains solely in `TextureRegion`; it is not duplicated in the material. Filtering independently describes minification and magnification, while addressing independently describes horizontal and vertical behavior. Uniform `.nearest`, `.linear`, `.clampToEdge`, `.repeat`, and `.mirrorRepeat` presets keep common construction concise. Mip filtering remains absent until Pixl textures support mipmaps. The pixel-art default is nearest filtering, edge clamping, and `.normal` source-over blending matched automatically to the texture asset's recorded alpha processing; `.replace` disables blending. Independently constructed equivalent descriptions are value-equivalent. Future material families may expose their own typed descriptions rather than widening one universal public material bag.

The intended material capability direction includes tint/modulation, opacity, normal maps and strength, emission maps, colour, and strength, mask textures, roughness, alpha cutoff, and other shader-specific parameters justified by Pixl-provided material families. This records the intended feature horizon, not final property placement. Before implementing that fuller material phase, stop for a dedicated design session covering which values belong to `Sprite`, `Sprite.Material`, per-instance records, shared material records, or texture maps; how lit/unlit behavior is selected; how mask channels are defined; and how sharing and mutation behave. Do not infer those decisions during implementation.

The provisional `SpriteRenderer` and internal GPU `Quad` have been removed. Pixl's common rendering path creates an ordinary render pass from the callback's `Frame` and `RenderTarget`, while an advanced Pixl path accepts a game-created pass so custom commands can share it. Direct PixlFoundation and PixlPlatform APIs remain available when a game deliberately wants to control execution and pass recording itself. Game control over render-pass boundaries is therefore available rather than mandatory.

## Submission, Resolution, and Batching

Sprite submission snapshots every relevant current value immediately. Later mutation cannot alter an earlier submission from the same frame: submitting a normal-blended sprite, changing it to additive, then submitting again produces two submissions with their respective states. No retained sprite identity or engine-owned scene object is required for the ordinary path.

`RenderQueue`
: Pixl's public, long-lived two-dimensional submission domain. `GameContext` owns the ordinary default queue and `Game.renderQueueSettings` supplies its fixed positive capacity, so normal game initialization does not construct or pass it around. A game deliberately importing PixlFoundation may also construct a queue directly. Submission never grows storage; exceeding configured capacity is a programmer error. Entities submit model-to-world values but do not encode or project them. A standalone entity may treat this as its ordinary position, rotation, and scale; a future parent-local hierarchy must compose its parent transforms before submission. Camera/view state belongs to execution rather than an individual sprite. Independent queues still serve genuinely independent destinations such as a pixel-art world and native-resolution UI. The unqualified name is intentional while Pixl has no 3D submission API; naming can be reconsidered when one exists.

`Render execution`
: The existing `Game.render(on:output:frame:time:context:)` callback remains Pixl's render callback; the queue architecture does not replace it. Game code submits each entity once without passing a camera or output. `context.render(through:to:frame:clear:)` creates the ordinary pass and consumes the default queue. `context.render(through:to:on:)` consumes it into a game-created `RenderPassEncoder`. Both resolve the camera exactly once at execution.

Pixl resolves the Pixl2D camera and destination into a primitive Foundation execution-view record containing projection and world-space visible bounds. The initial single view covers its complete render target; viewport/scissor state enters with the later exposed multi-view feature. Neither PixlFoundation nor PixlPlatform receives `OrthographicCamera` or any other dimensional camera type. Projection remains pass/view data and is applied with each instance's model-to-world transform during GPU vertex processing; Player, Character, and other submitted values never need camera access.

The initial Pixl convenience exposes one camera only. Foundation execution nevertheless accepts retained contiguous view records, with the single-player path supplying a one-element view buffer. This preserves the validated multi-view design without prematurely exposing multiplayer API. A later split-screen convenience can supply several resolved views to the same execution: lowering, union culling, layer binning, ordering, shared instance records, and material resolution remain shared, while view ordinal streams, consecutive batch spans, viewport/projection state, and draws remain view-specific. Compatible views of one target may record through one render pass with an internal view loop; incompatible destinations may require separate passes without repeating the shared CPU preparation.

Pixl automatically consumes and resets its default queue after the complete render attempt, on success or failure. Failure reset prevents partially recorded work from being retried or carried into a later frame. PixlFoundation publicly exposes primitive sprite snapshots, view records, execution buffers, texture-resource storage, and explicit `execute`/`reset` operations so a direct user controls that lifecycle; automatic reset is Pixl convenience policy rather than hidden Platform behavior. A later multi-view Pixl call resets only after all requested views have completed.

`SpriteRenderResources` is PixlFoundation's public device-wide sprite GPU resource owner. It shares geometry, texture resolution, samplers, and pipeline variants across queues. Each queue has one permanently paired `SpriteRenderWorkspace` containing only its fixed-capacity unsafe material-slot cache and instance-upload scratch. This prevents queue-local slot collisions without duplicating GPU resources or introducing hot-path collections. Pixl owns one shared resource set and one workspace for its default queue; direct Foundation users control the same lifecycle explicitly. Encoding remains serialized unless a later design adds synchronization around the shared caches.

`RenderTexture` is Pixl's context-owned high-level colour texture for render-then-sample workflows. Its initializer creates one GPU texture with render-attachment and sampled usage, registers the same resource as a logical `TextureAsset`, and records its expected alpha representation. Pixl resolves it to a low-level `RenderTarget` only while recording a pass. Render calls without a queue preserve the existing default-queue convenience and always clear; overloads taking an explicit queue require a `RenderInitialState` of `.clear(colour)` or `.preserve`. Custom queues receive lazily retained workspaces sharing the context's sprite GPU resources. Filtering remains material state on the sprite sampling the completed render texture, so one low-resolution result may be composited with nearest filtering alongside independently linear-filtered content.

RenderQueue is broader than a physical sprite batch. It initially accepts only sprites, but may later coordinate triangles, shapes, or other 2D families in one authoritative order. Each family retains its own compatible GPU batching and upload path; Foundation may share storage, cache, and lifetime infrastructure without forcing different vertex layouts or shaders into one draw.

Pixl lowers Pixl2D values into primitive SIMD/matrix records, logical resource identities, compact keys, ranges, and byte storage appropriate to PixlFoundation. PixlFoundation does not store semantic `Triangle`, `Quad`, or `Sprite` values merely because those were the game-facing source. PixlPlatform receives only resolved low-level resources and explicit commands.

Pixl may initially capture one convenient fixed-stride submission snapshot containing world bounds, scaled transform columns, normalized texture-coordinate origin and scale, logical texture identity, complete sampler description, blend mode, layer, local order, and submission ordinal. Foundation execution does not repeatedly traverse that wide authoring snapshot. Lowering writes several compact ordinal-aligned streams whose records interleave only fields consumed together:

- bounds records contain world-space minimum and maximum coordinates;
- ordering records contain layer, local order, and the layer's resolved dense slot;
- draw records contain one compact compatibility key;
- instance records contain transform columns, translation, texture-coordinate origin and scale, and packed tint.

The shared ordinal is the join key between streams. This keeps each traversal contiguous without forcing culling, ordering, batching, and upload to fetch unrelated fields. These retained CPU execution streams remain separate from public values and the final GPU upload ABI. The built-in instance record is five `SIMD2<Float>` values plus RGBA8 tint with an explicitly enforced 48-byte stride shared by the Metal and WGSL layouts. Material resolution replaces repeated sampler and blend descriptions with compact slots before batching.

Material and draw compatibility resolution is value-keyed. A material-property change derives the key for the new value and selects an existing cached state when one exists; only a genuinely unseen complete description takes the cold creation path. Closed built-in fields may use packed keys or direct indexing rather than general-purpose `Hasher` in the hot path. Animation within the same sheet normally changes instance texture coordinates; blend changes pipeline compatibility; texture changes resource compatibility.

Foundation resolves a logical texture only when its compact material slot first needs native state. Equivalent later submissions use the retained resolved material directly, and a compatible batch binds its pipeline, texture, and sampler once. Dictionaries are confined to lazy resource creation and never participate in steady-state queue execution.

Equivalent complete sampler descriptions share one native sampler, and equivalent complete pipeline descriptions share one native pipeline. PixlFoundation owns these device/runtime-level caches and their lifetimes, so one submission domain cannot invalidate resources used by another. Explicit resources created directly through `PixlPlatform.Device` retain caller-owned lifecycle. Steady-state submission performs no native-resource creation or allocation, but is not assumed to be zero-cost; key derivation, lookup, ordering, and instance writes remain measurable.

Shared sampler, pipeline, and related render resources initially resolve lazily on the first render that needs an unseen complete descriptor. That cold path may create a native resource and the Pixl render operation therefore remains throwing. Equivalent later intent reuses the cached resource. Prewarming is deferred until a real hitch or measurement justifies adding another lifecycle surface.

Render data is separated by update frequency and stored as fixed-stride interleaved records:

- Frame/pass records contain values such as camera transforms, time, and lighting shared by many draws.
- Material records contain values and resolved resources shared by a compatible batch.
- Instance records contain transform, texture coordinates, tint, and other values unique to one submitted sprite.

Public descriptions, retained CPU records, and GPU upload layouts are separate representations. Internal records use explicit, verified alignment and padding appropriate to Swift and each shader ABI. Reusable per-frame or ring-buffer regions prevent CPU writes from overwriting submitted GPU work. Dirty tracking applies only if a later feature introduces persistent mutable GPU records; ordinary immediate value submission simply writes the current snapshot. A stable mutable material slot may later coexist as an optional value handle with identity semantics for large shared parameter storage, but it is not required for ordinary sprites.

Pixl's one-second performance summary separately accumulates queue lowering, culling, layer binning, ordering, batch formation, and visible-instance compaction/copy time. These values measure only their named CPU stages; native command submission and GPU execution remain outside them. The Game currently prints the latest completed summary every five seconds.

Pixl uses distinct shader families when shading algorithms materially differ, such as textured sprites, lit sprites, or signed-distance-field rendering. Frame/material/instance frequency does not imply separate shaders: one shader family may consume all three record types. Small feature selections may lower without divergent control flow, but material flags do not replace fixed-function pipeline variants such as blend state.

Differences in texture, sampler, blend mode, layer, or game category do not require independent submission systems. Separate ordered submission domains are useful for genuinely independent destinations, such as a low-resolution offscreen pixel-art world and native-resolution window UI; they may still share Foundation caches. Within a domain, authoritative order is `(layer, local order, submission ordinal)`. Batching combines only consecutive compatible submissions and never reorders sprites merely to manufacture larger batches.

Foundation culls submitted bounds through one contiguous scalar traversal. For each submission it tests every execution view, stores a compact visibility mask, and appends the ordinal once when any view can see it. The core render queue does not maintain a per-sprite spatial grid, retained scene identity, or dirty spatial membership. Frame-local and retained uniform-grid variants were isolated and rejected: both added cache-hostile indirection, lifecycle machinery, and maintenance cost while losing to the contiguous scan for the dense, commonly visible sprite workload. Games or future domain libraries may still spatially accelerate persistent world objects, tilemap chunks, or other coarse groups before submission; that concern does not replace Foundation's cheap render-time bounds check over submitted values.

The union-visible ordinals are counted into generation-stamped dense layer slots. Only active slots are sorted by their public layer value, then prefix offsets scatter submissions into contiguous per-layer ranges. Each ordering key packs unsigned local order in the high 32 bits and submission ordinal in the low 32 bits. Stable radix passes process only order bytes that vary within that layer. This preserves authoritative `(layer, local order, submission ordinal)` order without comparing whole records or imposing a public maximum layer value.

The ordered union is traversed once. Each set visibility bit appends the shared source ordinal to that view's contiguous ordinal stream, while a draw-key change closes the current consecutive batch span. Views therefore share bounds records, instance records, layer work, ordering, and material resolution while retaining the filtering, batch boundaries, and draws that genuinely differ per camera. Foundation retains one ordinal-aligned CPU instance stream, then compacts only each visible view's ordered records into a reusable 48-byte GPU upload stream. Projection remains pass/view data rather than being baked into submitted sprite transforms.

The same execution boundary supports future 3D workflows: Pixl3D cameras resolve perspective view/projection state while submitted objects retain model-to-world transforms. Three-dimensional rendering will use its own mesh, depth, frustum-culling, material, batching, and upload family rather than forcing sprites through the 2D implementation; it does not require cameras or dimensional meaning to enter PixlPlatform.

Analytic 2D SDF shapes are a separate render family rather than a sprite material or game-facing wrapper around sprites and shapes. The initial source catalogue is every fixed-parameter primitive documented by Inigo Quilez at `https://iquilezles.org/articles/distfunctions2d/`; its public names, parameters, and explicit parameter-compatible shader/storage families must be catalogued before implementation. Arbitrary polygon is a variable-length outlier deferred until it receives a deliberate representation rather than silently inflating every fixed-parameter shape.

The fixed-parameter catalogue is: circle; rectangle/rounded rectangle; segment; rhombus; trapezoid; parallelogram; equilateral, isosceles, and arbitrary triangles; uneven capsule; pentagon, hexagon, and octagon; hexagram and regular star; pie, cut disk, arc, ring, and horseshoe; vesica and moon; rounded cross, egg, heart, cross, and rounded X; ellipse; parabola and parabola segment; quadratic Bezier; blobby cross; tunnel; stairs; quadratic circle; hyperbola; cool S; and circle wave. Polygon alone remains deferred. Oriented boxes are expressed by ordinary rectangle geometry plus `Transform2D`, avoiding a duplicate authoring concept; formula-local orientation parameters remain only where they change the primitive itself, such as arcs.

Shape GPU storage uses explicit fixed-stride families rather than one maximum payload: compact fixed-parameter primitives consuming at most four scalar parameters and extended point-defined primitives such as arbitrary triangles and quadratic Beziers. Open formulas use the appropriate payload family and produce their useful visible width through analytic stroke. Solid and gradient paint select separate shader/pipeline variants so solid shapes do not pay a texture sample or carry gradient-atlas data. Family selection participates in consecutive batch compatibility but never changes authoritative queue ordering.

The public construction style is `Shape(.circle)` and `Shape(.circle(radius: 20))`. Each leading-dot convenience returns the same concrete geometry type accepted explicitly by forms such as `Shape(Circle())`; no public geometry protocol, generic `Shape`, `Path` production, or type-erased visual wrapper is involved. Header examples prefer the discoverable leading-dot form. Shapes are retained mutable values like sprites and submitted directly through overloads such as `queue.submit(shape, transform:)`; games do not need to know how the queue shares or separates renderer families.

Shapes support canonical unit sizing or explicit dimensions, modifier-style fill and stroke, universal analytic rounding through either `Shape(.rect, rounding: 8)` or `.rounding(8)`, and `.antialiasing(.smooth)` or `.antialiasing(.hard)` with `.smooth` as the default. Rounding dilates any fixed-parameter shape's signed boundary and expands its conservative raster and culling bounds by the same local radius. The default style is a white fill, no stroke, normal blending, and layer/order zero. Stroke is centred by default, with inside and outside alignment available. Fill and stroke coverage partition one analytic outer coverage so aligned strokes cannot reveal a transparent seam. Analytic distance produces fill coverage, stroke/annular coverage, rounding, and antialiasing without texture filtering. Nearest/linear filtering is irrelevant to direct analytic rendering; when shapes are rendered into a low-resolution render texture, the later composite sprite's filtering controls scaling.

Initial shape submission deliberately matches sprites: `queue.submit(shape, transform: transform)`. Dimensions, rounding, and stroke widths are local/world units affected by the same `Transform2D` semantics as sprites. `Shape` exposes familiar mutable `layer`, `order`, `blendMode`, and horizontal `isFlipped` properties; flipping mirrors local x and may be visually irrelevant for symmetric primitives. Filtering and texture addressing do not belong to analytic shapes. Screen-space/UI layout is a separate future concern and does not shape the initial API.

`PixlGraphics.Gradient` is dimension-independent retained colour-ramp data closely matching SwiftUI's `Gradient`: `init(colors:)`, `init(stops:)`, nested `Stop(color:location:)`, and public stops. Gradient construction and shape styling are cold-path operations. Linear, radial, and angular placement belong to shape fill styles and use shape-local normalized coordinates. Colour arrays require at least one colour and synthesize evenly spaced locations; one colour is constant. Explicit stops require at least one finite `0...1` location, are sorted during construction, and equal locations represent a hard transition. Atlas colours use the renderer's premultiplied representation.

For steady-state GPU performance, arbitrary gradients compile once into 256-sample rows of a shared fixed-capacity 2D lookup atlas. A gradient shape then carries compact atlas coordinates and performs one linearly filtered lookup regardless of stop count; different gradients retain one shared texture/sampler binding and can remain batch-compatible. Solid fills use a separate no-sample path. `RenderQueue.Settings.gradientCapacity` defaults to 256 unique resolved gradients. Rendering does not traverse, copy, allocate, or hash gradient stop arrays per frame. Transient-shape lifetime diagnostics are not part of the current plan.

Shape execution shares submission ordinals, bounds, multi-view culling, layer binning, stable ordering, visibility distribution, consecutive batch formation, and metrics with sprites, but owns separate aligned family-specific instance streams, encoders, pipelines, and a small set of uber-style SDF shader families. Families should group compatible formula structure and parameter layouts so fixed-stride records retain cache locality and branches remain coherent within batches. Existing 48-byte sprite GPU records, sprite shaders, texture/material resolution, and sprite pipeline compatibility remain unchanged; the shared CPU ordering representation gains only the minimum family/source discrimination and must be measured later.

Simple analytic shapes use existing platform drawing capabilities. Dynamic boolean SDF composition of independently transformed operands would require variable operand storage and likely a portable fragment-readable buffer binding; union, smooth union, intersection, subtraction, composition builders, and per-child styling are therefore deliberately outside the initial shape scope. Ordinary primitive shapes must not pay composition storage or shader cost.

`Sprite.Material.BlendMode`
: Portable composition intent selected by a sprite material. Its initial cases are `.replace` and source-over `.normal`. Pixl lowers `.normal` to premultiplied source-over for default `.premultiplied` texture assets and straight-alpha source-over for `.passthrough` assets; the alpha representation therefore participates in material and pipeline compatibility without a shader branch or per-draw validation. Metal and WebGPU lower the resolved shared state to native blend factors. Additional modes require their colour and alpha equations plus accepted input representation to be agreed before expanding this enum.

## Platform Asset Capability

`AssetSource`
: Rooted platform capability that reads bytes for a validated logical `AssetPath`. Its optional `AsyncStream<AssetChange>` reports file-level source changes without imposing asset formats or reload policy on the platform layer.

macOS resolves the game-provided asset path relative to the Game package that declares `AssetSettings`. `AssetSettings` captures that declaration's `#filePath`; the adapter removes its `/Sources/...` suffix without searching the filesystem, then appends the configured path. Absolute paths bypass package-relative resolution. macOS reads directly from that directory and monitors recursive file changes with FSEvents. Pixl owns decoding, caching, dependency decisions, and reload failure policy. Same-size texture changes are written asynchronously through the platform writer; rendering does not poll for changes.

`Assets.load(texture:)` and `Assets.load(sound:)` throw `AssetError`. Required startup assets therefore fail explicitly instead of becoming optional values with logged errors.

Browser packaging copies `Game/Assets`, generates a manifest, and preloads those files before starting WASM. `PixlWasmPlatform` exposes the resulting in-memory bytes through the same synchronous `AssetSource` contract used by Pixl during game initialization. Browser builds do not monitor assets for changes.

PNG structure parsing and pixel decoding are shared Swift code in `PixlGraphics`. It uses the vendored Apple Swift Binary Parsing core and a Pixl-owned zlib/DEFLATE, scanline-filter, colour, transparency, and Adam7 implementation. Platform image frameworks are not part of PNG decoding.

Pixl's high-level texture loader treats decoded PNGs as colour textures. It premultiplies RGB by alpha once on the cold load and on every hot reload by default, before GPU upload; `.passthrough` retains decoded channels for deliberate straight-alpha use. Cache identity includes path and alpha processing because the two modes produce distinct GPU resources. `PixlPlatform` remains raw: texture bytes supplied directly through its device API retain caller-defined representation.

Initial creation and hot reload share one texture-preparation path for decoding and alpha processing. `ReloadMonitor` is format- and resource-agnostic: it only coalesces noisy `AssetChange` values per path. Pixl's asset reloader owns registered texture and sound destinations, source reads, same-size texture policy, writes, sound invalidation, and reload reporting.

## Portable Audio

`AudioSettings`
: Startup-only fixed capacities. `maxSoundCount` is the total number of resident `Sound` resources, `maxVoiceCount` is the simultaneous active native-voice limit, and `maxBusCount` is the number of game-created flat buses. Prepared playback controllers consume no voice slot. The master output is separate and does not consume a bus slot.

`Sound`
: Opaque generational handle for decoded resident samples. Pixl currently decodes WAV in shared Swift code into planar `Float32`, mono or stereo. Supported WAV payloads are 8/16/24/32-bit integer PCM and 32-bit IEEE float. Compressed formats and streaming sources remain future additions.

`Playback`
: Reusable reference controller created by `Audio.prepare` without starting or allocating a native voice. It strongly retains the shared audio controller and owns `play`, `pause`, `stop`, `volume`, `pan`, `rate`, `loop`, and `bus`. Initial configuration is volume `1`, pan `0`, rate `1`, looping disabled, and the master bus. `play` starts a new voice or resumes a paused live voice; `pause` preserves its playhead; `stop` destroys the active voice but leaves the controller reusable, and controller deinitialization also stops its active voice. Volume, pan, and rate changes update both stored configuration and a live voice. Loop and bus configuration apply when a new voice starts. Pitch shifts naturally with rate. A finished voice is retired lazily when controlled or when voice capacity is needed, so there is no per-frame reaper.

`Bus`
: Nonoptional flat routing target with an owned volume property initially set to `1`. Every prepared playback defaults to `Audio.masterBus`; game-created buses come from throwing, nonoptional `Audio.makeBus()`. Games assign semantic meaning such as music, effects, or voices, persist their volume values, then recreate buses and restore those values on launch; bus identities are runtime-only. Backends may still represent direct master routing with an internal absent handle. Buses feed the master output; nested graphs and effects are not part of the current contract.

`AudioDevice`
: Portable low-level resource/playback boundary. Shared `AudioEngine` creates prepared controllers and owns active handles, capacity, validation, buses, voice lifetime, control values, master volume, and sound replacement. Master volume starts at `1`. Concrete adapters only create native sample/voice/bus resources and perform primitive playback operations when a controller becomes active. Controller getters use portable stored state and never synchronously query a native audio graph. Metal uses AVFAudio; the browser uses Web Audio.

`SoundWriter`
: Optional backend-owned replacement/invalidation capability for a stable `Sound` handle. macOS asset changes arrive from the existing recursive event stream; Pixl coalesces each per-path event burst, reads, and decodes off the game loop. A valid content replacement restarts active voices from the beginning with their existing playback controllers and controls; paused voices remain paused. Removal immediately stops and retires active voices but retains prepared controllers and configuration. Their next `play` throws `AudioError.resourceUnavailable(.sound)` until valid content reappears, then explicitly playing uses the replacement. Invalid replacement data retains the last valid sound. Browser-packaged assets remain an immutable build-time snapshot for now.

Native completion handlers only set an atomic flag. Cleanup is demand-driven; completion performs no task creation, logging, allocation, or engine lock acquisition.

The macOS adapter owns one private serial `.utility` QoS audio-control queue. It creates and operates every AVFAudio engine, buffer, mixer, player, and varispeed node on that queue; game/render callers only perform fixed-capacity handle bookkeeping and enqueue commands. A native bus mixer is attached when created but connects downstream only while at least one voice is connected; its final voice removal disconnects it again. Audio hardware configuration notifications enqueue recovery on the same queue, so preparing or restarting a stopped engine never blocks frame work. Core Audio owns the real-time rendering thread. No route polling runs in the game loop.

Web Audio already separates its control and rendering threads internally. The current single-threaded WASM adapter issues lightweight `AudioContext` graph-control calls from the browser control thread; a stricter separation of those calls requires a future AudioWorklet/worker messaging backend. Browsers may initially suspend the context until a user gesture. Pixl keeps the game running and retains logical voice timelines while output is unavailable, then starts or resumes their sources when the context becomes active.

## Shaders and Pipelines

`ShaderFunction`
: Portable shader entry-point name. `PixlGraphics` publishes built-in names as static members on this type. It carries no artifact or backend-library ownership.

Concrete adapters own their built-in shader sources. SwiftPM compiles `PixlMetalPlatform`'s `.metal` files into the target's default library; `PixlWasmPlatform` embeds its WGSL source. Pipeline creation resolves `ShaderFunction.name` against that adapter-owned library or module. Pixl currently has no public custom-shader loading or registration API.

`RenderPipelineDescriptor`
: Startup description of shader functions, vertex input layout, and attachment format. Exact primitive topology is not pipeline state in Pixl's Metal-first interface; it is supplied to `drawPrimitives`. Backends that require topology at pipeline creation own/cache the corresponding native variants.

`VertexLayout`
: Fixed-capacity startup description of vertex-buffer streams and shader attributes. It describes GPU byte layout only; games own their Swift vertex types and bytes.

## Render Recording

`RenderPassDescriptor`
: Attachment/load/store description used to begin one render pass. It contains no frame-storage bookkeeping.

`RenderPassEncoder`
: Metal-shaped public recorder. Callers set pipeline/resource state and then issue draws. Current commands include pipeline, persistent vertex buffers, small vertex bytes, larger frame-owned vertex/instance data, fragment texture/sampler bindings, and instanced primitive/indexed draws.

`RenderCommand`
: Package-only compact command representation stored by `Frame`. It is not public game vocabulary. Resource commands store `ResourceID` rather than copying full descriptors into every recorded command.

`PrimitiveTopology`
: Exact primitive interpretation supplied to `drawPrimitives`: point, line, line strip, triangle, or triangle strip.

`IndexType`
: Portable index element width: `uint16` or `uint32`. `drawIndexedPrimitives` takes the index buffer directly, matching Metal. WebGPU, Vulkan, and DirectX adapters bind/cache that buffer privately before their indexed draw command.

Commands for a pass must be recorded contiguously. `Frame` preallocates command storage from startup-only `RenderSettings.frameCommandCapacity`; recording performs no allocation or dynamic dispatch. Game-provided render and queue settings are authoritative: the internal runtime forwards them unchanged rather than silently widening capacities.

## Dynamic Data and Resource Slots

Pixl's public direction is stage/resource-specific encoder intent, matching Metal: vertex/fragment buffers, bytes, textures, and samplers; compute encoders imply the compute stage. Public bind groups and dynamic-offset flags are not current Pixl concepts.

`setVertexBytes` copies at most 4 KiB immediately into fixed-capacity `Frame` byte storage. Metal lowers it to native inline bytes. WebGPU copies those recorded bytes through a fixed-capacity adapter-owned uniform buffer and one reusable dynamic-offset bind group.

`setVertexData` copies larger transient vertex or instance bytes into the same fixed-capacity `Frame` storage and binds the recorded range as a vertex-buffer slot. Metal copies the completed frame bytes into one of three retained shared upload buffers and retires each slot only after command-buffer completion. WebGPU copies the range into its retained immediate buffer. Persistent or caller-owned data still uses explicit `Buffer` resources.

Dynamic CPU-to-GPU transfer storage, upload rings, WebGPU bind groups, Vulkan descriptor sets, and DX12 descriptor allocation are private adapter mechanisms. Before adding general buffer-write/copy or readback APIs, define their GPU-completion retirement and readback lifetime. Do not expose a generic per-call write API that allocates staging resources or synchronizes CPU/GPU execution.

## Required Future Depth

Compute is required and must use the same encoder-command direction: compute pipeline state, buffer/texture resource slots, access modes, and dispatch commands. Compute output must feed later render passes in the same frame.

Other explicit gates include WebGPU texture/sampler lowering, multiple color attachments, depth/stencil, richer blend modes, multisampling, richer texture dimensions/mips, copy commands, dynamic bytes, readback, and profiling counters. Add each through playable Game needs without widening existing modules into shallow configuration bags.

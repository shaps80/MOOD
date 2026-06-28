# Renderer Shape API And SDF Plan

MOOD should expose a familiar, SwiftUI-inspired shape API in `Pixl`, then let
each platform renderer lower that platform-neutral description into its own GPU
work.

The first implementation is intentionally narrow: dynamic primitive shapes for
UI and simple effects. It should not become a general vector graphics renderer.
The API should still be shaped so a more complete path renderer can be added
later without changing ordinary caller code.

This plan is strongly informed by Randy Gaul's article, "2D Rendering with
SDF's and Atlases":

https://randygaul.github.io/graphics/2025/03/04/2D-Rendering-SDF-and-Atlases.html

Future implementers should read that article before building the backend. Its
discussion of tight quads, per-instance SDF data, batching, and shader-side SDF
evaluation strongly supports the approach described here.

## Goals

- Add composable shape and path authoring primitives to `Pixl`.
- Keep public names and call patterns close to SwiftUI where practical.
- Support simple dynamic UI shapes without making callers think about renderer
  internals.
- Preserve primitive identity so renderers can lower common shapes to optimized
  SDF paths.
- Keep `Pixl` platform-independent.
- Allow WebGL2, Metal, and future renderers to implement the same semantics with
  their own backend-specific pipelines.
- Batch many primitive shape draws without changing visual order.
- Support fill and stroke as separate operations where the caller can apply
  either or both.
- Support an initial portable subset of blend modes for shapes and sprites.
- Use premultiplied alpha internally.

## Initial Shape Set

The first version supports individual primitive shapes:

- rectangle
- rounded rectangle
- ellipse
- circle
- capsule
- single line segment paths

`Circle` is a convenience shape that resolves to an ellipse in a square rect.
`Capsule` resolves to a rounded rectangle with radius derived from the smaller
axis.

There is no public `Line` shape in the first version. UI separators can be
expressed as rectangles, rounded rectangles, or capsules. Arbitrary line
segments can be expressed with `Path.move(to:)` plus `Path.addLine(to:)`.

The initial renderer only needs to treat a single `move(to:)` followed by a
single `addLine(to:)` as a line segment. Multi-segment stroked paths are future
work.

## Non-Goals For V1

- Arbitrary Bezier curves.
- General compound path fill semantics.
- Even-odd fill.
- Masks.
- Text.
- Boolean shape operations.
- `lineJoin`.
- Dash patterns.
- Geometric merging of overlapping filled shapes.
- Expanding rounded rectangles or ellipses into polygon approximations as the
  default representation.
- Arbitrary custom shaders.
- Post-processing effects.
- Noise, blur, glow, drop shadows, or other multi-pass effects.

Batching compatible shape draws is a goal. Merging multiple shapes into one
mathematical filled region is not.

## Core Types

`Shape` should mirror the familiar SwiftUI concept. It belongs in `Pixl`.

```swift
protocol Shape {
    func path(in rect: Rect) -> Path
}
```

Built-in shapes should include:

```swift
Rectangle
RoundedRectangle
Ellipse
Circle
Capsule
```

The exact scalar types should follow existing `Pixl` conventions. If the project
already has `Vec2`, `Size`, `Rect`, or `Color`, use those rather than inventing
duplicates.

`ShapeStyle` should be protocol-shaped so call sites can grow naturally later:

```swift
protocol ShapeStyle {
    func resolve() -> Color
}
```

For the first version, `Color` is the only required concrete style. `Color`
should conform to `ShapeStyle`.

Gradients, textures, materials, and other style kinds are future work. Do not
add them in V1.

Hot renderer data should store resolved colors, not protocol values.

## Current Sprite Render State

`Sprite` is a renderable sprite instance, not an asset definition.

The entity/sprite lifecycle migration is already done. `Sprite` carries the
render state needed to draw itself:

```swift
public struct Sprite {
    public var position: Vec2
    public var size: Vec2
    public var material: Material
    public var layer: RenderLayer
    public var blendMode: BlendMode
    public var opacity: Double
    public var tint: Color
}
```

`SpriteAsset` remains asset metadata. Do not put tint, opacity, blend mode, or
layer on sprite assets.

`Material` remains the source:

```text
color
texture/source rect
```

`Sprite` owns how that source is drawn.

`Color` alpha and `Sprite.opacity` are separate concepts. Color alpha is part of
the source color. Sprite opacity is a whole-sprite multiplier. Final alpha
multiplies them.

WebGL2 and Metal apply `blendMode`, `opacity`, and `tint` for sprites.

## Render Layers

`Pixl` owns the `RenderLayer` type as a small sortable render-order value. It
does not own MOOD-specific layer constants.

Good:

```swift
public struct RenderLayer: Comparable, Sendable {
    public let rawValue: Int
}
```

MOOD defines semantic layer constants in MOOD code:

```swift
extension RenderLayer {
    static let terrain = RenderLayer(rawValue: 100)
    static let entity = RenderLayer(rawValue: 200)
}
```

`Sprite.layer` is assigned by game code, usually during entity preparation.
`Pixl.Game` must not decide that entity sprites belong on a specific
named layer.

This mirrors collider layers: Pixl owns the mechanism, game code owns the
semantic constants.

## Blend Modes

Shapes and sprites should share the same blend mode model.

The initial blend mode set is:

```swift
enum BlendMode {
    case normal
    case additive
    case multiply
    case screen
    case replace
}
```

`normal` is the default alpha-blended mode.

`additive` is useful for light, glow-like contributions, impacts, particles, and
other effects where source color adds energy to the destination.

`multiply` and `screen` are useful for common color compositing effects. Their
V1 implementation must be portable across WebGL2 and Metal. If exact
Photoshop-style semantics require framebuffer fetch or an offscreen composite
pass, document the chosen approximation rather than hiding a platform-specific
difference.

`replace` means source overwrites destination. It is the no-blending mode.

Typical `replace` uses:

- opaque primitives that should not alpha-blend
- debug or intermediate rendering where accumulation would be misleading
- future offscreen passes
- future mask or render-target work

The first implementation does not need automatic opaque detection. A renderer may
add a measured fast path later for commands that are definitely opaque.

### Blend Mode Batching

Blend mode is render state. Compatible primitives can batch only when their
blend state is compatible.

Draw order still wins. Do not reorder commands across layers or within a layer
just to group blend modes unless the existing render-order model explicitly
allows it.

Example:

```text
normal sprite
normal shape
additive sprite
normal sprite
```

may become:

```text
normal batch
additive batch
normal batch
```

That is acceptable. Blend modes are expected to be used intentionally, not on
every primitive by default.

## Premultiplied Alpha

MOOD should use premultiplied alpha internally for textures, shapes, and final
fragment output.

Premultiplied alpha means:

```text
stored.rgb = color.rgb * color.a
stored.a   = color.a
```

Benefits:

- cleaner texture edges
- cleaner SDF antialiasing
- better tinting behavior
- fewer transparent-pixel fringe artifacts
- standard blend equations for common 2D rendering

Asset authors should not need to prepare special premultiplied PNGs. The engine
or asset loading path should handle conversion once when decoding/uploading
textures.

Do not premultiply the same texture twice. Asset metadata or loader ownership
should make the texture alpha convention explicit enough that each texture has
one known path.

Shape colors can be premultiplied while resolving render command data or in the
shader. Do not leave that decision ambiguous inside a backend.

The normal blend equation should be the premultiplied-alpha form:

```text
out.rgb = src.rgb + dst.rgb * (1 - src.a)
out.a   = src.a   + dst.a   * (1 - src.a)
```

Backends should map this to fixed-function blending where possible.

## Source Modifiers

Blend modes describe how final source color combines with the destination.
Brightness, tinting, opacity, grayscale, contrast, saturation, and similar
operations are source-color modifiers. They happen before blending.

Conceptually:

```text
sprite texture or shape color
-> source modifiers
-> premultiplied source color
-> blend mode
-> framebuffer
```

The current sprite source modifier fields are:

```swift
var blendMode: BlendMode = .normal
var opacity: Double = 1
var tint: Color = .white
```

Sprites and shapes should both be able to use the same blend mode, opacity, and
tint model.

Potential future source modifiers:

- brightness
- contrast
- saturation
- grayscale amount

Do not add these until there is a real caller. Keep the initial implementation
to blend mode, opacity, and tint unless gameplay/UI work needs more.

Noise, blur, glow, drop shadows, masks, and arbitrary filters should not be
added as basic source modifiers. Those belong to a later material, shader, mask,
or post-processing design.

## Sprite Renderer State

Current behavior:

- `Sprite.tint` modulates both textured sprites and shape materials.
- `Sprite.opacity` multiplies final source alpha for the whole sprite.
- `Sprite.blendMode` selects the backend blend state.
- Existing visuals remain unchanged for default sprites:
  `tint == .white`, `opacity == 1`, `blendMode == .normal`.

Conceptually:

```text
source = material color or sampled texture
source = source * tint
source.a = source.a * opacity
source.rgb = source.rgb * opacity, when output is premultiplied
source -> blend mode
```

For textured sprites, avoid splitting batches by tint/opacity. Prefer adding
per-instance color data to the sprite instance buffer so many differently tinted
sprites can still share one texture batch.

The current `RenderBatch` model groups textured sprites by texture and blend
mode. Tint and opacity are per-instance data, so differently tinted sprites can
still batch together when texture and blend mode match.

Blend mode remains batch/render state. A batch cannot mix sprites with different
blend modes unless the backend implements a different strategy. Preserve draw
order over batch size.

## Path

`Path` is the underlying shape description.

The first version should support these construction forms:

```swift
Path(rect)
Path(roundedRect: rect, cornerRadius: radius, style: .circular)
Path(ellipseIn: rect)
```

and a builder form:

```swift
Path { path in
    path.move(to: point)
    path.addLine(to: point)
    path.addRect(rect)
    path.addRoundedRect(in: rect, cornerRadius: radius, style: .continuous)
    path.addEllipse(in: rect)
}
```

Exact initializer labels should follow SwiftUI when there is an obvious match.
If existing project naming differs for geometry types, keep SwiftUI-like method
names while using project-native types.

Path commands must preserve primitive identity. A rounded rectangle should stay
an `addRoundedRect` command. An ellipse should stay an `addEllipse` command.
They should not be flattened into line segments as part of the public path
construction API.

Preserving identity lets renderers classify commands into optimized primitive
draws.

## Render Style

`Shape` and `Path` describe geometry only. They should not carry color or
renderer state in the caller-facing API.

Immediate drawing passes render intent at the draw boundary:

```swift
let style = RenderStyle(
    fill: .blue,
    stroke: .white,
    strokeStyle: StrokeStyle(lineWidth: 2),
    blendMode: .normal,
    opacity: 1,
    tint: .white
)

context.draw(path, style: style, layer: .entity)
context.draw(Capsule(), in: rect, style: style, layer: .entity)
```

`RenderStyle` stores optional fill and stroke colors plus fill/stroke options,
blend mode, opacity, and tint. This is only needed for immediate/context
drawing where there is no sprite to provide render state.

Retained game visuals should use shape materials on sprites:

```swift
Sprite(
    position: position,
    size: size,
    material: .shape(Capsule()),
    layer: .entity,
    tint: .blue
)
```

`Sprite.tint`, `Sprite.opacity`, `Sprite.blendMode`, and `Sprite.layer` provide
the render state for shape materials. Shape materials render as a white fill
modulated by sprite tint and opacity. This makes prototype sprites, solid
rectangles, and simple entity visuals participate in normal sprite lifecycle,
visibility culling, ordering, and batching.

`Material.color` should not exist. Solid colored sprites should use:

```swift
material: .shape(Rectangle())
tint: .red
```

There should be no `fillAndStroke` convenience API in V1.

## Styles

The initial fill style only needs antialiasing:

```swift
struct FillStyle {
    var antialiased: Bool = true
}
```

The initial stroke style should include line width and line cap:

```swift
struct StrokeStyle {
    var lineWidth: Float = 1
    var lineCap: LineCap = .butt
}
```

`lineJoin` should not exist until multi-segment stroked paths are implemented.

Supported line caps:

- butt
- square
- round

For a stroked single segment:

- butt cap maps to a rectangular segment.
- square cap maps to a rectangular segment extended by half the line width.
- round cap maps to a capsule segment.

For rectangle, rounded rectangle, ellipse, circle, and capsule strokes, line cap
does not affect rendering.

`lineWidth` must be clamped or rejected if it is invalid. Do not let negative or
NaN widths reach renderer hot paths.

## Fill Rules

V1 does not support even-odd fill or general compound fill rules.

Individual primitive shapes can be filled and stroked correctly. Compound paths
may be accepted only when they can be treated as independent primitive draws.
They should not claim full vector-path fill semantics.

If a caller creates a compound path that cannot be represented by V1 primitive
lowering, prefer an explicit unsupported path over silently rendering incorrect
fill-rule behavior.

Acceptable handling options:

- omit the unsupported command with a debug assertion
- emit a clearly unsupported render command that renderers can ignore/log
- fail fast in debug builds

Do not pretend overlapping compound paths have correct union, winding, or
even-odd semantics.

## Renderer Lowering

Renderers should classify path commands into primitive render work:

```text
addRect               -> rect SDF primitive
addRoundedRect        -> rounded-rect SDF primitive
addEllipse            -> ellipse SDF primitive
move + addLine stroke -> segment SDF primitive
```

The public API is shape/path based. SDF is an implementation strategy, not a
public API concept.

### Classification Rules

The first renderer pass should classify only these cases:

- A path containing exactly one `addRect` command.
- A path containing exactly one `addRoundedRect` command.
- A path containing exactly one `addEllipse` command.
- A path containing exactly `move(to:)` and `addLine(to:)`, when submitted with
  a `RenderStyle` stroke.
- Built-in shapes that resolve to one of the above paths.

Everything else is outside V1.

### Primitive Command Data

The platform-neutral render command should contain resolved, allocation-free data
that renderers can batch directly. A practical shape primitive needs:

```text
kind
bounds or endpoints
corner radius, when relevant
optional fill color
optional stroke color
stroke width
line cap, for single line segments
fill antialias flag
stroke antialias flag
blend mode
opacity/tint or resolved source modifier data
draw layer/order
```

Use existing render ordering and layer mechanisms. Do not invent a separate
ordering model for shapes.

Do not put `ShapeStyle` protocol values, closures, or high-level `Path` builders
inside hot renderer command buffers.

## SDF Strategy

For the supported primitive set, SDF rendering is the preferred backend strategy.

Each primitive can be drawn as a tight quad with per-instance shape data. The
fragment shader evaluates signed distance, antialiasing coverage, fill coverage,
and stroke coverage.

This approach should work across:

- WebGL2
- Metal
- future GPU backends

The same high-level render command semantics should remain available to future
software or platform-native renderers, even if their implementation differs.

### Shape SDF Expectations

Expected backend mappings:

- Rect: box SDF.
- Rounded rect: rounded box SDF. `.circular` uses quarter-circle corners.
  `.continuous` uses a calibrated continuous corner approximation that keeps
  the same-radius footprint close to `.circular`.
- Capsule: rounded box SDF with radius equal to half the smaller axis, using the
  selected rounded corner style.
- Circle/ellipse: ellipse SDF.
- Stroked single segment: segment SDF with butt, square, or round cap behavior.

The renderer should use tight quads where practical. The quad should cover only
the primitive bounds plus any stroke/antialias expansion required for correct
edge coverage.

The shader should use local primitive coordinates so color, future gradients,
and distance evaluation are independent of absolute screen position.

## Batching

The renderer should batch compatible shape primitives heavily.

The intended backend shape is:

```text
one shape pipeline
one quad mesh
instance data per primitive
many instances per draw call
```

Draw order still matters, especially with alpha blending. Batching should
preserve the order promised by `Pixl` render commands.

When primitives share pipeline and blend state, preserving order should not
require one draw call per shape.

V1 should prefer one shape pipeline per backend if possible. If a backend needs a
small number of pipelines for practical reasons, keep that detail hidden inside
the platform renderer.

Shape type branching in shaders should be considered a backend performance
tradeoff. It is acceptable for V1 to use a shape-kind value in instance data and
select the SDF formula in the shader. Later optimization can split batches by
shape kind if measurement shows that to be faster.

## Antialiasing

Antialiasing should be controllable through `FillStyle`.

Stroke antialiasing should also be controllable through stroke APIs or
`StrokeStyle` if the implementation chooses to store it there. Caller-facing
usage should remain close to SwiftUI.

Shader implementations should prefer branchless selection where practical, for
example computing hard and smooth coverage and selecting between them with a
numeric antialiasing flag.

Conceptually:

```text
soft coverage = smooth distance edge
hard coverage = step distance edge
coverage = mix(hard coverage, soft coverage, antialias flag)
```

The exact implementation belongs to each renderer.

The antialias flag is a visual control, not a separate primitive type. It should
not force separate public API concepts or duplicate render command types.

## Platform Split

`Pixl` owns:

- `Shape`
- `Path`
- `ShapeStyle`
- `FillStyle`
- `StrokeStyle`
- `BlendMode`
- sprite render state
- platform-neutral render commands
- primitive identity and draw ordering

Platform renderers own:

- SDF shader code
- instance buffer layout
- GPU pipeline setup
- backend-specific batching
- blending details
- premultiplied-alpha texture upload/conversion details

`Pixl` must not import or mention WebGL, Metal, JavaScriptKit, DOM APIs, AppKit,
UIKit, or other platform frameworks.

## Current Implementation Status

Implemented:

- Existing sprite render state is honored by WebGL2 and Metal.
- `Sprite.tint` and `Sprite.opacity` work for textured sprites and shape
  materials.
- `Sprite.blendMode` selects blend state.
- `Pixl` exposes `Shape`, `AnyShape`, `Path`, `RenderStyle`, `ShapeStyle`,
  `FillStyle`, and `StrokeStyle`.
- `RoundedCornerStyle` supports `.circular` and `.continuous`.
- `Rectangle`, `RoundedRectangle`, `Ellipse`, `Circle`, and `Capsule` exist.
- `Material.shape(...)` stores shape geometry for retained sprite and tile
  rendering. `Material.color` has been removed.
- `Path` preserves `move`, `addLine`, `addRect`, `addRoundedRect`, and
  `addEllipse` commands.
- `RenderContext` accepts `context.draw(path, style:layer:)` and
  `context.draw(shape, in:style:layer:)`.
- WebGL2 and Metal lower supported primitives to SDF shader batches.
- Compatible shape primitives batch while preserving draw order.

Remaining/future:

- Browser and native visual QA by a human.
- More exact vector-path semantics for compound paths.
- Curves.
- `lineJoin`.
- Gradients and richer `ShapeStyle` implementations.
- Post-processing, masks, blur, glow, noise, and arbitrary custom shaders.

The project currently prefers these validation commands:

```text
swiftly run swift build --scratch-path .build/host --target Pixl
swiftly run swift build --swift-sdk swift-6.3.2-RELEASE_wasm
```

Do not run browser-serving flows or full test suites unless explicitly asked.

## V1 Acceptance Criteria

V1 is acceptable when visual testing confirms:

- Existing sprite render state is honored by WebGL2 and Metal.
- `Sprite.tint` and `Sprite.opacity` work for textured sprites and shape
  materials.
- `Sprite.blendMode` selects `normal`, `additive`, `multiply`, `screen`, or
  `replace` behavior.
- `Rectangle`, `RoundedRectangle`, `Ellipse`, `Circle`, `Capsule`, and
  single-segment lines render correctly.
- Immediate shape/path drawing takes explicit `RenderStyle`.
- Retained solid visuals use `Material.shape(...)` plus sprite tint.
- There is no `fillAndStroke` API.
- `StrokeStyle` does not expose `lineJoin`.
- `FillStyle` supports `antialiased`.
- Shapes and sprites use the same initial blend modes: `normal`, `additive`,
  `multiply`, `screen`, and `replace`.
- Fragment output uses premultiplied alpha.
- Unsupported compound path fill semantics are not silently misrepresented as
  correct.
- Compatible primitive shapes batch while preserving draw order.

## Implementation Principle

The API should make simple shape authoring pleasant now while leaving room for a
real path renderer later.

The first implementation should optimize individual primitives, not solve all
vector graphics.

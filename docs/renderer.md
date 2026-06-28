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

## Path

`Path` is the underlying shape description.

The first version should support these construction forms:

```swift
Path(rect)
Path(roundedRect: rect, cornerRadius: radius)
Path(ellipseIn: rect)
```

and a builder form:

```swift
Path { path in
    path.move(to: point)
    path.addLine(to: point)
    path.addRect(rect)
    path.addRoundedRect(in: rect, cornerRadius: radius)
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

## Fill And Stroke

`fill` and `stroke` should follow SwiftUI-style shape operations.

Examples of the intended call shape:

```swift
Path(roundedRect: rect, cornerRadius: 5)
    .strokedPath(.init(lineWidth: 2))
    .fill(.red)

Circle()
    .stroke(lineWidth: 1)
    .fill(.red, style: .init(antialiased: false))

Path { path in
    path.move(to: .zero)
    path.addLine(to: .init(x: 20, y: 0))
}
.fill(.blue, style: .init(antialiased: false))
```

These operations do not draw immediately. They produce shape/path values carrying
enough render intent for a later draw submission.

Do not add an API shaped like this:

```swift
context.draw(path.fill(.red).stroke(.white, lineWidth: 2))
```

That pattern is not the target call site. Callers should be able to create a
styled shape/path value first, then submit that value to the context:

```swift
let shape = Circle()
    .stroke(lineWidth: 1)
    .fill(.red, style: .init(antialiased: false))

context.draw(shape)
```

The draw boundary should be explicit:

```swift
context.draw(path)
```

`context.draw` resolves the path/style state into platform-neutral render
commands. Platform renderers then lower those commands into GPU work.

There should be no `fillAndStroke` convenience API in V1.

### Required Operations

Implement instance-style operations for the built-in shapes and paths. They
should feel like SwiftUI modifiers, not renderer commands:

```swift
extension Shape {
    func fill<S: ShapeStyle>(
        _ content: S,
        style: FillStyle = FillStyle()
    ) -> some Shape

    func stroke(
        style: StrokeStyle
    ) -> some Shape

    func stroke(
        lineWidth: Float = 1
    ) -> some Shape
}

extension Path {
    func fill<S: ShapeStyle>(
        _ content: S,
        style: FillStyle = FillStyle()
    ) -> Path

    func stroke(
        style: StrokeStyle
    ) -> Path

    func stroke(
        lineWidth: Float = 1
    ) -> Path

    func strokedPath(_ style: StrokeStyle) -> Path
}
```

The exact return types and overload set can be adjusted to fit Swift type
constraints. The caller-facing behavior should remain SwiftUI-like.

`stroke` means "render this shape as a stroke." `strokedPath` means "convert the
stroke outline into a fillable path." For V1, `strokedPath` only needs to work
for shapes that can be lowered to the supported primitive set.

### Fill And Stroke Together

A shape may carry both fill and stroke intent. The API should allow this using
normal SwiftUI-style operations, not a special combined call.

For V1, if implementing exact SwiftUI chaining semantics becomes too broad, it
is acceptable to support the common primitive cases explicitly and document any
unsupported chaining cases in code comments or tests.

The renderer command emitted by `context.draw` should contain optional resolved
fill and optional resolved stroke data where the primitive supports both. This
avoids submitting two unrelated primitives when one SDF primitive can compute
both fill and stroke coverage.

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
- A path containing exactly `move(to:)` and `addLine(to:)`, when stroked or
  converted with `strokedPath`.
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
- Rounded rect: rounded box SDF.
- Capsule: rounded box SDF with radius equal to half the smaller axis.
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
- platform-neutral render commands
- primitive identity and draw ordering

Platform renderers own:

- SDF shader code
- instance buffer layout
- GPU pipeline setup
- backend-specific batching
- blending details

`Pixl` must not import or mention WebGL, Metal, JavaScriptKit, DOM APIs, AppKit,
UIKit, or other platform frameworks.

## Implementation Sequence

An agent implementing this should work in this order:

1. Add `Pixl` path/style/shape types without touching platform renderers.
2. Add tests or compile-time examples for the intended API shape.
3. Lower supported paths into platform-neutral render primitives.
4. Teach existing render contexts to accept `context.draw(path)`.
5. Implement WebGL2 SDF primitive rendering.
6. Implement Metal SDF primitive rendering.
7. Verify `Pixl` still builds on host.
8. Verify the browser/Wasm build only when explicitly requested by the user.

The project currently prefers these validation commands:

```text
swiftly run swift build --scratch-path .build/host --target Pixl
swiftly run swift build --swift-sdk swift-6.3.2-RELEASE_wasm
```

Do not run browser-serving flows or full test suites unless explicitly asked.

## Acceptance Criteria

V1 is done when:

- `Pixl` exposes `Shape`, `Path`, `ShapeStyle`, `FillStyle`, and `StrokeStyle`.
- `Rectangle`, `RoundedRectangle`, `Ellipse`, `Circle`, and `Capsule` exist.
- `Path` can preserve `move`, `addLine`, `addRect`, `addRoundedRect`, and
  `addEllipse` commands.
- Fill and stroke use SwiftUI-like names and call shape.
- There is no `fillAndStroke` API.
- `StrokeStyle` does not expose `lineJoin`.
- `FillStyle` supports `antialiased`.
- Unsupported compound path fill semantics are not silently misrepresented as
  correct.
- WebGL2 and Metal can render the supported primitives using backend-owned SDF
  pipelines.
- Compatible primitive shapes can be batched while preserving draw order.

## Implementation Principle

The API should make simple shape authoring pleasant now while leaving room for a
real path renderer later.

The first implementation should optimize individual primitives, not solve all
vector graphics.

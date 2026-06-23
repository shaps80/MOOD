# Camera Architecture

MOOD treats the camera as game state, not renderer state.

Platform layers apply the final camera transform. They do not decide what the
camera follows, how it moves, when it transitions, or which gameplay moment owns
camera control.

## Core Decisions

- `GameCore` owns camera state and camera behavior.
- Sprites remain in world coordinates.
- Platform renderers convert world-space sprites into screen-space draw calls by
  subtracting the final camera origin.
- The camera stores an origin for now. Origin means the top-left world coordinate
  visible through the logical-resolution viewport.
- `logicalResolution` remains the game viewport size. It is not renamed.
- Level/world size is separate from logical resolution.
- Camera anchoring must not hardcode gameplay roles such as player or boss.
  Game code chooses anchors from points or entity IDs.
- Top-down and side-on games use the same orthographic camera model. They differ
  in camera behavior, composition, and constraints.

## Model

The intended shape is:

```text
CameraRig
  anchor
  tracking
  composition
  constraints
  effects
  transition
```

`Camera` is the resolved viewport:

```text
Camera
  origin
  viewportSize
  visibleBounds
```

## Anchors

Anchors answer: what should the camera frame?

Initial anchor forms:

- `point(Vec2)`
- `entities([Entity.ID])`

A single entity is represented by one ID. A group is represented by several IDs.
Room centers, scripted reveal points, and hand-authored cutscene positions are
represented as points.

Do not add hardcoded anchors such as `player`.

## Tracking

Tracking answers: how does the camera move toward the desired frame?

Tracking modes are mutually exclusive. Examples:

- snap
- smooth follow
- scripted transition

Initial implementation uses snap only. Smooth tracking and transitions should be
added when gameplay needs camera pans, boss reveals, cutscenes, or tuned follow
behavior.

## Composition

Composition answers: how should the selected anchor be framed?

Composition settings are mostly composable. Examples:

- offset from anchor
- lookahead
- dead zone
- vertical or horizontal bias

Initial implementation supports offset.

## Constraints

Constraints answer: where is the camera allowed to be?

Constraints are composable. Examples:

- world bounds
- room bounds
- axis locks
- one-way scrolling

Initial implementation supports bounds plus optional axis locks.

Resolution order:

```text
desired origin
-> apply axis locks
-> clamp to bounds
-> base camera
```

## Effects

Effects answer: how is the final camera perturbed after base framing?

Effects should layer on top of the resolved base camera. They should not modify
the anchor or feed back into follow math.

Examples:

- shake
- recoil
- scripted additive offset
- hit-stop jitter

Initial implementation supports additive offset only.

## Renderer Contract

Renderer behavior is intentionally boring:

```text
screenPosition = sprite.worldPosition - camera.origin
```

Renderers should not know whether the game is top-down, side-on, in a cutscene,
following an entity, revealing a boss, or shaking from an impact.


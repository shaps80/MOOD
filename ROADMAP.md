# Pixl Roadmap

This file is a compact view of where Pixl is and what should happen next. It is not a history of completed work.

## Maintenance

- Keep only current capabilities and unfinished work; this is not project history.
- Architecture belongs in `CONTEXT.md`; accepted measurements in `PERF.md`.

## Current State

- One game-facing Swift path runs on macOS/Metal and browsers/WebGPU.
- Pixl provides lifecycle, timing, semantic input, audio, assets, metrics, and macOS hot reload over portable `PixlPlatform` contracts. PixlPlatform supplies allocation-free keyboard, gamepad, and high-fidelity physical mouse state and per-frame events on macOS and Web.
- Pixl2D provides value-semantic sprites, analytic SDF shapes, gradients, materials, regions, sheets, animation, layers, transforms, and orthographic cameras.
- Pixl2D provides game-owned discrete collision for rectangles, normalized polygons, analytic circles, and analytic capsules through a balanced dynamic AABB-tree broad phase and exact narrow phase.
- Pixl currently includes a provisional fixed-step `PlatformerController` with configurable walk/run, variable and buffered jumps, coyote time, air jumps, dashing, crouching/rolling, wall sliding, and wall jumping.
- Spatial, graphical, and normalized input values use compact `Float` storage throughout portable layers; time and accumulated durations remain `Double`.
- Fixed-capacity immediate submission performs shared culling, ordering, batching, instance compaction, and indexed instanced sprite, analytic-shape, and polygon drawing without steady-state growth by design.
- Game-provided render and queue capacities are authoritative. The current Game sizes them from actual visible submission needs rather than total world population.
- `OrthographicCamera` exposes visible world bounds. The Game validates game-owned coarse spatial selection with 100,000 animated world sprites while Pixl retains precise final culling.
- Context-owned render textures support independent offscreen queues, render-then-sample composition, target-format pipeline variants, preserve/clear initial state, and per-sprite filtering on Metal and WebGPU.
- PixlUI retains and invalidates scenes, propagates environment values, lays out in logical points, and lowers styled controls and analytic shapes through the shared Metal/WebGPU rendering path. Current shapes include continuous and uneven rounded rectangles, capsules, circles, and container-relative concentric rectangles.
- The Game verifies movement, input, layered animation, filtering, blend modes, pause/time scaling, music, assets, metrics, visuals, and hot reload.

## Near-Term Work

### First Playable Game Gate

Complete the remaining items before expanding the engine surface:

- [ ] Streaming audio so long-form playback no longer requires fully decoded resident storage.
- [ ] Bitmap-font text for game HUD, scoring, and PixlUI menus.
- [x] Small deterministic 2D collision vocabulary suitable for the first game.
- [x] Minimal 2D platformer movement: velocity integration, gravity, grounded state, and collision response.

With these complete, build the first proper Retro Invaders game using the existing sprites, animation, input, PixlUI pause menu, music, sound effects, and scoring paths.

### Next — Streaming Audio

- [ ] Add an explicit streaming audio source for long-form playback without fully decoded resident storage; music is the first consumer, not a special-case API.

### Bitmap Font Text

- [ ] Decide the initial pre-baked bitmap-font metadata format, comparing an existing format such as AngelCode BMFont with a compact Pixl-owned asset format.
- [ ] Define the smallest font domain values: atlas texture, Unicode glyph lookup, bounds, advance, bearing, line height, and kerning.
- [ ] Replace placeholder `Text` measurement with font metrics and lower visible glyphs through the existing ordered sprite batching path.
- [ ] Support alpha-mask foreground styling and one atlas page first; defer vector rasterization, shaping, fallback, and multi-page atlases.
- [ ] Cache text layout and glyph submissions with the retained Scene so unchanged text performs no steady-state work.

### First Game and 2D Rendering

- [ ] Route future backgrounds, tiles, players, enemies, and UI through the agreed immediate submission path as the Game needs them.
- [ ] Add named irregular `TextureAtlas` regions when the Game needs them.
- [ ] Add a visual `TileSet` mapping from game-owned tile identifiers to atlas regions without introducing engine-owned world or tilemap storage.

### GPU Foundations

- [ ] Generalize the current frame-safe vertex upload lifetime only when another stage needs buffer writes or copy commands; define a separate completion-safe readback lifetime before exposing readback.

### Audio

- [ ] Add compressed formats only when a playable Game need justifies decoder and packaging costs.
- [ ] Move Web Audio graph control behind an AudioWorklet or worker boundary only if profiling shows current control-thread work affecting frames.

### Collision

- [x] Keep Rect, Polygon2D, Circle2D, and Capsule2D collision in Pixl2D, with game-owned `CollisionWorld2D` and no PixlPlatform, PixlFoundation, entity, or automatic runtime ownership.
- [x] Define the first deterministic collision vocabulary: contacts, rays, stable collider identity, static/dynamic mode, one-way layer masks, directed contact phases, transformed polygon colliders, and cached analytic circle/capsule colliders.
- [x] Provide centralized fixed-tick collision reporting plus exact allocation-free overlap and ray queries.

### Minimal 2D Physics

- [x] Provide fixed-step 2D motion state with velocity and configurable gravity integration.
- [x] Resolve the first game's body against static rectangle and polygon surfaces with deterministic position correction and velocity response.
- [x] Expose grounded/contact state supporting variable and buffered jumps, coyote time, air jumps, dashing, crouching/rolling, wall sliding, and wall jumping.
- [ ] Replace the Game character's temporary AABB with `Capsule2D` and wire ground, head, and wall sensing through the controller's existing probe configuration.
- [ ] Make crouching change the physical collider and prevent standing when overhead geometry blocks the standing shape.
- [ ] Add focused regression coverage for dash, crouch/roll, wall movement, and compound state transitions.
- [ ] Move the isolated provisional controller into `PixlPrototypes` when its collider integration is complete.
- [ ] Defer general rigid bodies, rotation, impulses, joints, restitution, friction, and continuous collision detection.

### Later Collision Scaling

- [x] Implement the initial balanced dynamic AABB-tree broad phase with contiguous unsafe storage, fat bounds, stackless traversal, and exact narrow-phase confirmation.
- [x] Lower game-defined collision layers and masks to fixed-width bitsets outside candidate hot paths.
- [ ] Benchmark representative dynamic-tree, pair-generation, phase-merge, and query workloads before considering parallel collection or alternate broad phases.
- [ ] Introduce `PixlConcurrency` only after a representative collision workload proves useful parallel depth and defines deterministic merging.

### In-Game Editing

- [ ] Add object picking, silhouette selection outlines, and 2D/3D gizmos.
- [ ] Add undo/redo for transforms, tile edits, and property changes.
- [ ] Later, add an asset browser with previews and atlas-region drag/drop.

### Platform Reach

- [ ] Carry the proven portable contract beyond macOS and WebAssembly to Windows, iOS, tvOS, and visionOS without leaking platform concepts upward.

## Later — Performance Verification

- [x] Establish a standalone deterministic representative CPU-frame benchmark on native and WASI, including mixed render preparation, collision work, correctness checksums, and native resident-memory reporting.
- [ ] Verify no steady-state CPU allocation once the Game has a representative workload.
- [ ] Profile material-key derivation, resolved-resource lookup, ordering, and instance writes separately so avoidable submission cost remains visible.
- [ ] Measure the representative bullets/enemies workload and a separate 10,000-visible-sprite stress case on native and browser, then record only accepted baselines in `PERF.md`.
- [ ] Prototype bitset-based culling and measure it against the current contiguous traversal; later investigate bitsets for collision filtering and physics simulation.


## Shaps Personal Notes (LLM ignore this!)

Over this week I want us to focus more on the following (not necessarily in this order):

- Streaming sound support
- Tilemap, Tileset, Atlas support
- Shapes via SDF
- Text (Bitmap at least)


Determinstic floating point
 - FastMath - disable on Window
 - Contractions = disable on Linux
 - macOS, webGPU??
 - Box2D does this so maybe ref that
 - sin/cos - custom implementations so its consistent
 - fast recipricol sqrt – intrinsics, don't use it!
 - Multi-threading - ordering needs to be determistic

 Determistic physics
 - Sort the results - single threaded (qsort, e.g.)
 - Better is a bitset - array of UInt64's
   - each bit represents the index of the body in array of bodies
   - or contacts, etc...

 Say you have 8 workers, each works has its own bitset represnting all the bodies
 When they're done with their work, back to single-threaded
 Takes those bitsets and OR them - giving the same result every time

 There are instrinsic instructions for iterating over the bitset INCREDIBLY fast even for 1M
 So you just use those intrinsics instructions to iterate
 Which covers determinsm without sorting

 Q: could bitsets be an option for really fast collision detection?!

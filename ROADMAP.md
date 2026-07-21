# Pixl Roadmap

This file is a compact view of where Pixl is and what should happen next. It is not a history of completed work.

## Maintenance

- Keep only current capabilities and unfinished work; this is not project history.
- Architecture belongs in `CONTEXT.md`; accepted measurements in `PERF.md`.

## Current State

- One game-facing Swift path runs on macOS/Metal and browsers/WebGPU.
- Pixl provides lifecycle, timing, semantic input, audio, assets, metrics, and macOS hot reload over portable `PixlPlatform` contracts.
- Pixl2D provides value-semantic sprites, analytic SDF shapes, gradients, materials, regions, sheets, animation, layers, transforms, and orthographic cameras.
- Fixed-capacity immediate submission performs shared culling, ordering, batching, instance compaction, and indexed instanced sprite/shape drawing without steady-state growth by design.
- Context-owned render textures support independent offscreen queues, render-then-sample composition, target-format pipeline variants, preserve/clear initial state, and per-sprite filtering on Metal and WebGPU.
- The Game verifies movement, input, layered animation, filtering, blend modes, pause/time scaling, music, assets, metrics, visuals, and hot reload.

## Near-Term Work

### First Game and 2D Rendering

- [ ] Route future backgrounds, tiles, players, enemies, and UI through the agreed immediate submission path as the Game needs them.
- [ ] Add named irregular `TextureAtlas` regions when the Game needs them.
- [ ] Add a visual `TileSet` mapping from game-owned tile identifiers to atlas regions without introducing engine-owned world or tilemap storage.

### GPU Foundations

- [ ] Generalize the current frame-safe vertex upload lifetime only when another stage needs buffer writes or copy commands; define a separate completion-safe readback lifetime before exposing readback.

### Audio

- [ ] Add an explicit streaming sound source; music should use streaming by default.
- [ ] Add compressed formats only when a playable Game need justifies decoder and packaging costs.
- [ ] Move Web Audio graph control behind an AudioWorklet or worker boundary only if profiling shows current control-thread work affecting frames.

### In-Game Editing

- [ ] Add object picking, silhouette selection outlines, and 2D/3D gizmos.
- [ ] Add undo/redo for transforms, tile edits, and property changes.
- [ ] Later, add an asset browser with previews and atlas-region drag/drop.

### Platform Reach

- [ ] Carry the proven portable contract beyond macOS and WebAssembly to Windows, iOS, tvOS, and visionOS without leaking platform concepts upward.

## Later — Performance Verification

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

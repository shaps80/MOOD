# Pixl Roadmap

This file is a compact view of where Pixl is and what should happen next. It is not a history of completed work.

## Maintenance

- Keep only current capabilities and unfinished work; this is not project history.
- Architecture belongs in `CONTEXT.md`; accepted measurements in `PERF.md`.

## Current State

- One game-facing Swift path runs on macOS/Metal and browsers/WebGPU.
- Pixl provides lifecycle, timing, semantic input, audio, assets, metrics, and macOS hot reload over portable `PixlPlatform` contracts.
- Pixl2D provides value-semantic sprites, materials, regions, sheets, animation, layers, transforms, and orthographic cameras.
- Fixed-capacity immediate submission performs culling, ordering, batching, instance compaction, and indexed instanced drawing without steady-state growth by design.
- The Game verifies movement, input, layered animation, filtering, blend modes, pause/time scaling, music, assets, metrics, visuals, and hot reload.

## Next — Game and Performance Verification

- [ ] Exercise independent offscreen-world and native-resolution UI submission destinations if their target formats expose distinct pipeline variants.
- [ ] Verify no steady-state CPU allocation.
- [ ] Profile material-key derivation, resolved-resource lookup, ordering, and instance writes separately so avoidable submission cost remains visible.
- [ ] Measure the representative bullets/enemies workload and a separate 10,000-visible-sprite stress case on native and browser, then record only accepted baselines in `PERF.md`.

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

- [ ] Add object picking, selection outlines, render previews, and gizmos.
- [ ] Add texture painting with staged texture updates.
- [ ] Add screenshot capture through GPU readback.

### Platform Reach

- [ ] Carry the proven portable contract beyond macOS and WebAssembly to Windows, iOS, tvOS, and visionOS without leaking platform concepts upward.

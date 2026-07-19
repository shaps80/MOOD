# Pixl Agent Notes

Pixl is a cross-platform Swift game engine. Its near-term goal is Raylib-like time-to-first-game built on modern, portable foundations rather than an OpenGL-shaped architecture.

## Collaboration

- Discuss design first unless the user explicitly asks to implement or change code.
- Keep architectural discussion short and focused on one decision at a time.
- Prefer explaining the smallest useful implementation shape; the user wants to write most implementation code personally.

## Architecture

- `PixlPlatform` owns only the lowest-level platform APIs: the minimum portable contracts and concrete adapters needed for higher layers to build consistent functionality across platforms.
- Only concrete platform-adapter targets may import operating-system, graphics, audio, windowing, or browser frameworks. The portable `PixlPlatform` target and every higher-level library must remain platform-agnostic Swift.
- Rendering, input, audio, assets, and runtime capabilities belong in `PixlPlatform` only at their lowest portable boundary. Conveniences and game-facing abstractions belong in higher layers.
- Keep GPU APIs close to Metal's direct encoder/resource-slot model and validate them against modern DirectX. WebGPU and Vulkan adapters own their binding, descriptor, caching, and pipeline-variant machinery.
- Keep `PixlPlatform` dimension-agnostic and camera-agnostic. Build 2D, 3D, text, UI, and camera facilities above it.
- Entities, spawning, world ownership, physics, and particle simulation are game concerns or separate future libraries, not platform or engine-foundation responsibilities.
- Performance is a first-class constraint. Avoid steady-state allocation and dynamic dispatch in hot paths unless measurement justifies them.

## Project Documents

- Read `CONTEXT.md` before proposing or changing low-level platform vocabulary or architecture. Update it when those decisions change.
- Read `ROADMAP.md` for current progress, workstreams, and unresolved gates. Progress belongs there, not in this file.
- Read `PERF.md` before profiling or discussing performance baselines. Record only accepted results there.

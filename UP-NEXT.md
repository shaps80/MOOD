# Up Next

## Shared Sprite Rendering

Replace per-sprite GPU ownership and render-pass creation with one shared `SpriteRenderer`.

- [x] Keep `Sprite` as lightweight render data: texture region and flip state.
- [x] Make one renderer own the shared quad, sampler, and pipeline.
- [x] Let Game own the render pass and submit its sprite through the renderer.
- [x] Add game-defined render layers, retained high-water submissions, an ordered fast path, and stable fallback ordering.
- [x] Select packed horizontal or vertical animation strips with bounded, partial, or complete sheet ranges.
- [x] Composite sprite transparency through portable normal alpha blending on Metal and WebGPU.
- [ ] Route future backgrounds, tiles, players, enemies, and UI through that same renderer.
- [x] Preserve layer/submission order and use one draw per sprite for the first proof.
- Follow with retained high-water instance submission storage and compatible consecutive batching.
- Build named texture atlases, then visual tile sets, on that batching boundary.

Scalability goal: the first game may own 10,000 live entities. Entity storage, simulation, collision, and culling remain game concerns; the renderer consumes only visible sprite submissions. Its representative workload is hundreds of visible live bullets plus roughly 50 enemies, with a separate 10,000-visible-sprite stress case. Compatible sprites sharing atlas, layer, and blend state should collapse into a small number of instanced draws. Track live entities, visible/submitted sprites, batch count, draw count, ordering work, instance bytes, culling time, and collision time separately.

The 10,000-visible-sprite stress case is a performance requirement, not only a correctness test. For the primary case—already layer-ordered sprites sharing one atlas and blend mode—submission, batching, instance preparation, upload, command recording, and GPU execution must each remain comfortably below the frame budget with no steady-state allocation. Record native and browser CPU/GPU results separately before accepting a baseline in `PERF.md`.

Batch compatibility—not renderer ownership—is determined by render pass, pipeline/material state, texture, sampler, and future blend/depth/scissor state. Incompatible consecutive sprites flush the current batch internally; they do not require another renderer. A second renderer is only for separate device ownership or deliberately isolated capacity/lifetime.

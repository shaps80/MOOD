# Up Next

## Shared Sprite Rendering

Replace per-sprite GPU ownership and render-pass creation with one shared `SpriteRenderer`.

- [x] Keep `Sprite` as lightweight render data: texture region and flip state.
- [x] Make one renderer own the shared quad, sampler, and pipeline.
- [x] Let Game own the render pass and submit its sprite through the renderer.
- [ ] Route future backgrounds, tiles, players, enemies, and UI through that same renderer.
- Preserve submission order and use one draw per sprite for the first proof.
- Follow with fixed-capacity instance submission and compatible consecutive batching.
- Build named texture atlases, then visual tile sets, on that batching boundary.

Batch compatibility—not renderer ownership—is determined by render pass, pipeline/material state, texture, sampler, and future blend/depth/scissor state. Incompatible consecutive sprites flush the current batch internally; they do not require another renderer. A second renderer is only for separate device ownership or deliberately isolated capacity/lifetime.

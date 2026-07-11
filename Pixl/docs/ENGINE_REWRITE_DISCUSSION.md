# Engine Rewrite Discussion Tracker

Purpose: capture design discussions before rewriting the engine. This document is discussion and capture only. Code changes are out of scope unless explicitly requested later. Entire discussion should be considered a learning exercise and discussed with that context. Teach me. DO NOT reference existing code during any discussion. I want fresh perspective.

Each section should be treated in isolation. For every topic, capture:

- current understanding
- decisions
- rejected options
- code samples or sketches
- parallelism options
- GPU-accelerated options
- open questions
- completion state

## Progress

- [ ] 3. High-performance 2D collision, physics, and physics bodies
- [ ] 4. Particle system design
- [ ] 5. Engine API, scene/level representation, and editor responsibilities
- [ ] 6. Input API and platform input coverage
- [ ] 7. Timer domains and scheduling

## Completed References

- [1. Engine Loop](<1. Engine Loop.md>)
- [2. Entities](<2. Entities.md>)

## 3. High-Performance 2D Collision, Physics, and Physics Bodies

Status: Not started

### Initial Scope

Discuss ideal 2D collision design independent of Pixl's current implementation, including broad phase, narrow phase, collision shapes, spatial partitioning, continuous collision detection, physics bodies, contacts, triggers, and deterministic arcade physics versus fuller rigid-body physics.

### Parallelism/GPU Considerations

Pending discussion.

### Decisions

- Pending.

### Completion Criteria

- [ ] Collision goals defined.
- [ ] Broad-phase candidates compared.
- [ ] Narrow-phase/body model decided or narrowed.
- [ ] Physics scope decided.
- [ ] Parallelism/GPU stance captured.

## 4. Particle System Design

Status: Not started

### Initial Scope

Design a simple initial particle system with a strong high-performance foundation, including CPU versus GPU simulation, emitters, particle buffers, pooling, sorting/blending, determinism, and platform portability.

### Parallelism/GPU Considerations

Pending discussion.

### Decisions

- Pending.

### Completion Criteria

- [ ] Feature scope defined.
- [ ] CPU/GPU simulation split decided.
- [ ] Buffer/lifetime model captured.
- [ ] Renderer integration captured.
- [ ] Parallelism/GPU stance captured.

## 5. Engine API, Scene/Level Representation, And Editor Responsibilities

Status: Not started

### Initial Scope

Discuss the engine-facing API for scenes and levels, using tools like Tiled for inspiration. Capture what an editor should own versus what the engine runtime should own.

### Parallelism/GPU Considerations

Pending discussion.

### Decisions

- Pending.

### Completion Criteria

- [ ] Scene/level responsibilities mapped.
- [ ] Tiled-style concepts reviewed.
- [ ] Runtime/editor boundary captured.
- [ ] API direction chosen or narrowed.
- [ ] Parallelism/GPU stance captured.

## 6. Input API and Platform Input Coverage

Status: Not started

### Initial Scope

Current input is intentionally limited and semantic. That helped early simplicity, but it means new input needs often require touching platform code. Discuss whether the engine should expose broad, consistent, platform-neutral input primitives, while individual games map those primitives into semantic actions.

Possible direction:

- Engine exposes raw-ish keyboard, pointer, touch, controller, text, focus, and device state through a consistent API.
- Game maps engine input to semantic gameplay actions such as `moveLeft`, `jump`, `shoot`, or `pause`.
- Platform adapters normalize platform-specific input into Pixl input events/state.
- Games should not need platform code edits for normal input expansion.

### Parallelism/GPU Considerations

Probably not relevant, except input snapshots should be cheap, immutable per frame, and safe to read during the single-threaded simulation tick.

### Decisions

- Pending.

### Completion Criteria

- [ ] Current input model understood.
- [ ] Engine-owned input primitive set discussed.
- [ ] Game-owned semantic action mapping discussed.
- [ ] Platform adapter responsibilities captured.
- [ ] Debug/testing input needs captured.

## 7. Timer domains and scheduling

Status: Not started

### Initial Scope

Pixl does not currently have a detailed timer model. Discuss how games should represent cooldowns, invulnerability windows, spawn schedules, animation timers, UI timers, debug timers, delayed callbacks, and real-time versus simulation-time behavior.

Timer domains to discuss:

- simulation timers: advance only during fixed gameplay simulation
- presentation timers: advance during frame updates for visual/UI behavior
- real-time timers: follow elapsed platform time, even if gameplay is paused

Questions:

- Should timers be engine-provided primitives or game-level helpers?
- Should a timer pause automatically when gameplay pauses?
- Should timers support fixed-tick countdowns instead of seconds?
- Should scheduled callbacks be allowed, or should timers only expose elapsed/remaining state?
- How do timers interact with save/load and deterministic replay?

### Parallelism/GPU Considerations

Probably not relevant directly. Timers should be cheap to update and deterministic when attached to simulation time.

### Decisions

- Pending.

### Completion Criteria

- [ ] Timer domains defined.
- [ ] Simulation-time versus real-time behavior decided.
- [ ] Pause/resume interaction captured.
- [ ] Deterministic replay/save-load implications captured.

## Later Topics

Add more sections here as new concerns come up.

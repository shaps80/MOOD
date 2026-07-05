# Engine Rewrite Discussion Tracker

Purpose: capture design discussions before rewriting the engine. This document is discussion and capture only. Code changes are out of scope unless explicitly requested later. Entire discussion should be considered a learning exercise and discussed with that context. Teach me.

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

- [ ] 1. Main loop reliability and frame pacing
- [ ] 2. Entity storage, iteration, and ownership model
- [ ] 3. High-performance 2D collision, physics, and physics bodies
- [ ] 4. Particle system design
- [ ] 5. Engine API, scene/level representation, and editor responsibilities

## 1. Main Loop Reliability and Frame Pacing

Status: In discussion

### User Concern

Even with an almost empty game containing only a player and no meaningful collision work, a 60 FPS target can show frequent 1-2 FPS drops. That suggests loop reliability/frame pacing rather than raw gameplay workload.

### Current Pixl Approach

Pixl currently uses a fixed simulation step and variable render cadence on both native macOS and Web:

Sources:

- `Sources/PlatformMac/Runtime.swift:40` defines native fixed step.
- `Sources/PlatformMac/Runtime.swift:121` runs the native frame loop.
- `Sources/PlatformWeb/Runtime.swift:24` defines web fixed step.
- `Sources/PlatformWeb/Runtime.swift:56` runs the web frame loop.
- `Sources/Pixl/Game.swift:135` runs one simulation update.
- `Sources/Pixl/Game.swift:265` rebuilds render commands/batches.

```swift
accumulatedTime += max(rawDeltaSeconds, 0)

while accumulatedTime >= fixedTimeStep {
    game.update(delta: fixedTimeStep, input: inputState)
    audio.playSounds(game.drainSounds())
    accumulatedTime -= fixedTimeStep
}

renderer.draw(game: game)
```

The fixed step is derived from `preferredFps`, defaulting to 60 FPS:

```swift
var fixedTimeStep: Double {
    guard game.preferredFps > 0 else {
        return 1.0 / 60.0
    }

    return 1.0 / game.preferredFps
}
```

Observed current implications:

- Simulation delta is stable when updates run.
- Rendering is not interpolated between previous/current simulation states.
- If a frame arrives late, the loop may run multiple simulation updates before one draw.
- There is no visible accumulator clamp, max-update cap, panic/drop policy, or timing smoothing.
- Mac uses `MTKView.draw(in:)` as the render callback and sets `preferredFramesPerSecond`.
- Web uses `requestAnimationFrame`.
- Both platforms depend on the host display/runtime callback for cadence.

### Current Per-Tick Work

One `game.update` currently performs, at minimum:

- input/debug/time-scale handling
- frame event preparation
- entity `onUpdate` iteration
- system updates before post-collision
- movement/collision application
- contact detection
- collision callback dispatch
- system updates from post-collision onward
- camera update
- render frame rebuild
- render command sort
- render batch generation

Even an "empty" game is not only drawing one sprite; it still runs the whole pipeline.

### Current Hypotheses For 1-2 FPS Drops

These are discussion hypotheses, not measured conclusions:

1. Display callback jitter: `MTKView`/display scheduling may not deliver perfectly spaced 16.666 ms callbacks.
2. Accumulator threshold sensitivity: tiny timing variance can cause occasional skipped update or double update patterns.
3. No interpolation: render cadence variation is visually exposed instead of hidden by interpolation.
4. No clamp/cap: after any hitch, the loop can spend the next draw catching up.
5. Render rebuild every tick: frame commands, sort, and batches are regenerated after every simulation update.
6. Allocation/copy churn: arrays, sorted command rebuilds, existential entity calls, and collision temporary arrays can create jitter even if average cost is low.
7. Main-thread coupling: input, update, audio event dispatch, frame rebuild, and render submission all share the main actor/native callback path.

### Discussion Targets

- Decide whether Pixl should keep fixed-step simulation.
- Decide how rendering should behave between simulation ticks.
- Decide whether frame pacing should target deterministic simulation, visual smoothness, lowest latency, or configurable profiles.
- Decide what metrics are mandatory before rewrite decisions.
- Decide what the engine guarantees to game code: exact fixed delta, max updates per frame, dropped time behavior, interpolation alpha, etc.
- Discuss moving accumulator, clamping, interpolation, and pacing into Pixl instead of duplicating that policy in each platform.

### Preferred Direction Under Discussion

The platform layer should ideally own only platform time capture and presentation callbacks:

```swift
game.update(rawDelta)
renderer.draw(game, in: view)
```

Then Pixl owns the loop policy:

- receive raw platform delta
- clamp pathological raw delta values
- accumulate elapsed time
- run zero or more fixed simulation ticks
- cap catch-up work
- compute interpolation alpha
- prepare render-facing state

This keeps gameplay easier to reason about because game simulation remains single-threaded and fixed-step, while each platform adapter avoids reimplementing core timing rules.

Important naming note: this likely means splitting today's `game.update(delta:)` into two conceptual layers:

- public/platform-facing frame update: accepts raw frame delta
- internal simulation tick: accepts fixed simulation delta

### Frame Timing Instrumentation

Frame timing instrumentation means recording enough per-frame timing data to distinguish "the engine is slow" from "the platform callback arrived late" from "the loop did too much catch-up work."

Useful counters/timings:

- raw platform delta: time between display callbacks
- clamped delta: raw delta after engine safety limits
- accumulator before/after update
- simulation step count this frame
- update CPU time
- render-prep CPU time
- render-submit CPU time
- total frame CPU time
- interpolation alpha
- dropped/clamped time count
- max, average, percentile frame/update times over rolling windows

The important teaching point: FPS alone is a weak metric. A frame can "drop" because the callback came late, because CPU work exceeded budget, because the engine ran two catch-up ticks, because rendering blocked, or because measurement is averaged poorly. Instrumentation separates these causes.

### Options To Discuss

#### Fixed Step + Interpolated Render

Classic deterministic model:

```swift
while accumulator >= dt {
    previousState = currentState
    update(dt)
    accumulator -= dt
}

let alpha = accumulator / dt
render(interpolate(previousState, currentState, alpha))
```

Pros:

- deterministic simulation
- smoother visual motion under callback jitter
- easy replay/testing model

Costs:

- requires previous/current renderable state
- API must separate simulation state from presentation state
- interpolation policy needed per component/property

#### Fixed Step + Max Updates Per Frame

Add a catch-up cap:

```swift
let maxSteps = 4
var steps = 0

while accumulator >= dt && steps < maxSteps {
    update(dt)
    accumulator -= dt
    steps += 1
}

if steps == maxSteps {
    accumulator = 0
}
```

Pros:

- avoids spiral-of-death
- keeps render responsive after hitches

Costs:

- drops simulation time
- must define gameplay semantics of dropped time

#### Semi-Fixed Timestep

Use fixed steps for most updates, but consume leftover time up to a maximum. This can reduce visible jitter but weakens determinism.

#### Variable Timestep

Use actual `delta` for update. Usually worse for collision, physics, replay, and deterministic gameplay. Might remain useful for non-gameplay animation, UI, camera smoothing, or effects.

#### Decoupled Simulation And Render Threads

Run simulation on a dedicated loop/queue and render latest snapshot on display callback.

Pros:

- isolates display callback jitter from simulation
- can use spare cores

Costs:

- snapshot ownership complexity
- higher latency risk
- Swift data-race discipline required
- harder debugging
- Web support differs due browser threading constraints

### Parallelism Options

- Keep gameplay simulation single-threaded, but parallelize pure jobs inside a frame: broad-phase rebuild, particle simulation, animation sampling, visibility, render command preparation.
- Use double/triple-buffered immutable snapshots for render data.
- Use task/job system with frame-local arenas and deterministic join points.
- Avoid parallelizing arbitrary entity callbacks early; that requires strong API constraints around mutation, messaging, and ordering.

### GPU-Accelerated Options

Likely not useful for the core game loop itself. More relevant areas:

- GPU particle simulation.
- GPU sprite/instance expansion.
- GPU culling for very large worlds.
- Compute-based broad phase only for extreme entity counts, with high complexity and backend divergence.

Loop-facing GPU concern: do not block CPU waiting for GPU completion each frame. Rendering should be submitted asynchronously with bounded in-flight frames.

### Decisions

- Pending.

### Open Questions

- What exactly counts as unacceptable: measured FPS drop, visible stutter, input latency, or simulation drift?
- Are observed 1-2 FPS drops from macOS native, Web, or both?
- Is `preferredFramesPerSecond = 60` being tested on a 60 Hz, 120 Hz, or variable-refresh display?
- Should Pixl target 60 simulation Hz always, or allow 120/144 simulation profiles?
- Should the engine expose interpolation to game code or keep it internal?
- Should render frame rebuild happen once per display frame or after every simulation step?

### Completion Criteria

- [ ] Current loop behavior understood.
- [ ] Preferred loop model chosen.
- [ ] Frame pacing guarantees documented.
- [ ] Instrumentation plan agreed.
- [ ] Parallelism/GPU stance captured.

## 2. Entity Storage, Iteration, and Ownership Model

Status: Not started

### Initial Scope

Confirm `EntityStore` performance characteristics, intrusive/free-list design, ID generation behavior, iteration cost, mutation behavior during iteration, and whether the model is appropriate for a more capable engine.

### Parallelism/GPU Considerations

Pending discussion.

### Decisions

- Pending.

### Completion Criteria

- [ ] Current entity model understood.
- [ ] Desired storage model chosen or narrowed.
- [ ] Mutation/lifetime rules captured.
- [ ] Parallelism/GPU stance captured.

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

## Later Topics

Add more sections here as new concerns come up.

# PixlParticles Roadmap

Work through one decision at a time, in this order unless new evidence requires reordering.

## 1. Architecture

- Continue refining responsibilities and data flow as new behavior appears.
- Current boundary: simulation owns mutable state and interpolation metadata;
  rendering owns projection, culling, visual representation, and drawing.

## 2. Deterministic Simulation

- Fixed updates, Philox random streams, pause/resume, duration, deterministic
  replay, live scrubbing, and basic seeking are working end to end.
- Design periodic checkpoints so backward seeking restores nearby state instead
  of replaying every tick from zero.
- Preserve cross-version and cross-platform output as properties, events, and
  checkpoints are introduced.

## 3. Sequencing and State Over Time

- Define sequencing, timelines, and precise state-over-time authoring for Swift and the editor.
- Account for causal cohorts such as moving heads, distance-emitted trails, and death-triggered bursts.

## 4. Authoring and Runtime Representation

- Design small, composable Swift authoring types.
- Define lowering into allocation-conscious runtime data without existential costs in hot paths.
- Choose terminology for this lowering step.
- Extend the established unsafe AoSoA runtime storage as particle properties are
  added: separate property buffers, four particles per SIMD batch, and focused
  whole-buffer update passes.
- Keep public particles as complete snapshots independent of internal storage.

## 5. CPU and GPU Execution

- Define compute preferences and capability-driven fallback.
- Determine how events affect CPU execution, GPU execution, or hybrid approaches.
- The current production CPU motion pass is single-threaded and explicitly SIMD
  across particles. The macOS baseline is 0.641 ms per million particles.
- Rerun production AoSoA benchmarks on iPad and WebAssembly. WebAssembly requires
  both direct WMO compilation without `-num-threads` and `-Xcc -msimd128`.

## 6. Post-processing Ownership

- Decide where bloom and other post-processing are authored and owned.
- Define how multiple and nested particle systems can request different behavior.

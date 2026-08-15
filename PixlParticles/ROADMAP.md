# PixlParticles Roadmap

Work through one decision at a time, in this order unless new evidence requires reordering.

## 1. Architecture

- Define responsibilities and data flow.

## 2. Deterministic Simulation

- Define time, randomness, pause/resume, seeking, scrubbing, and repeatable execution.

## 3. Sequencing and State Over Time

- Define sequencing, timelines, and precise state-over-time authoring for Swift and the editor.
- Account for causal cohorts such as moving heads, distance-emitted trails, and death-triggered bursts.

## 4. Authoring and Runtime Representation

- Design small, composable Swift authoring types.
- Define lowering into allocation-conscious runtime data without existential costs in hot paths.
- Choose terminology for this lowering step.

## 5. CPU and GPU Execution

- Define compute preferences and capability-driven fallback.
- Determine how events affect CPU execution, GPU execution, or hybrid approaches.

## 6. Post-processing Ownership

- Decide where bloom and other post-processing are authored and owned.
- Define how multiple and nested particle systems can request different behavior.

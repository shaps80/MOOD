# PixlMemory Performance Baselines

These measurements are specific to the standalone PixlMemory package and its
Sandbox executable. Compare future results using the same build configuration
and similar runtime conditions.

## Sandbox CLI — Release Baseline

Recorded on 2026-08-31 before PixlMemory performs payload backing allocations.
The Sandbox constructs tracking metadata, representative memory plans, and an
arena, then waits in its command loop. It does not allocate any planned payload
memory.

| Measurement | Resident memory |
| --- | ---: |
| Observed release range | 3.60–3.80 MB |

This is the standalone CLI/process baseline, not PixlMemory-managed capacity.
Use it to detect process-memory changes as backing allocation and storage are
introduced. Exact hardware, operating-system build, sampling tool, and sample
count were not recorded for this initial observation.

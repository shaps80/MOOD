# Text Engine Roadmap

## Direction

Build a cross-platform text engine that is usable independently of Pixl. Pixl and PixlUI are clients of the engine, not its defining boundary.

Keep text layout and glyph/atlas work separate from renderer lowering. The engine should eventually produce ordered, pre-culled renderer primitives that make GPU and CPU integration straightforward for Pixl, other engines, and applications.

Start with efficient low-level data and algorithms. Add mid-level, TextKit 2-like abstractions only when they can be built cleanly on those primitives with measured overhead.

The final package name and target boundaries remain open.

## Current Focus

1. Complete the portable OpenType shaping and positioning foundation.
2. Define shaped-run records and property-based run segmentation.
3. Add bidirectional resolution and Unicode line-breaking opportunities.
4. Define line and paragraph layout records over positioned glyph runs.

## Established Decisions

- MSDF is the initial distance-field format.
- Glyph atlases are dynamic, memory-only, and generated per missing glyph on first use.
- Glyph generation and atlas packing have separate explicit input/output boundaries so compile-time tooling can reuse them later.
- Shaping and layout use font metrics and glyph IDs, never atlas placement.
- PixlText depends on PixlConcurrency; initial execution is one lane with later lane scaling kept internal.
- Hot text work uses contiguous, cache-aligned, data-oriented storage.
- SFNT parsing, Unicode normalization/script detection, GSUB single/ligature substitution, and GPOS glyph/class pair positioning are implemented in platform-agnostic Swift.
- Hot GSUB/GPOS execution uses indexed immutable plans and noncopyable contiguous glyph buffers.

## Open Design Gates

- Standalone package/target structure and Pixl/PixlUI adapter boundaries.
- Remaining GSUB/GPOS lookup coverage and feature policy.
- Exact low-level shaped-run, line, and paragraph records.
- Bidirectional and Unicode line-breaking implementation boundaries.
- Rasterisation and MSDF-generation implementation.
- Cache ownership, keys, invalidation, and storage lifetime.
- Paragraph and run scheduling thresholds.
- Renderer primitive format, culling contract, and CPU/GPU integration seams.
- Mid-level abstraction scope and sequencing.

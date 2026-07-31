# Text Engine Roadmap

## Direction

Build a cross-platform text engine that is usable independently of Pixl. Pixl and PixlUI are clients of the engine, not its defining boundary.

Keep text layout and glyph/atlas work separate from renderer lowering. The engine should eventually produce ordered, pre-culled renderer primitives that make GPU and CPU integration straightforward for Pixl, other engines, and applications.

Start with efficient low-level data and algorithms. Add mid-level, TextKit 2-like abstractions only when they can be built cleanly on those primitives with measured overhead.

The final package name and target boundaries remain open.

## Current Focus

1. Visually validate Unicode line-breaking opportunities.
2. Define a single positioned line record that selects opportunities against width.
3. Add wrapping and paragraph layout over positioned lines.
4. Add bidirectional resolution and script-specific shaping stages later.

## Established Decisions

- MSDF is the initial distance-field format.
- Glyph atlases are dynamic, memory-only, and generated per missing glyph on first use.
- Glyph generation and atlas packing have separate explicit input/output boundaries so compile-time tooling can reuse them later.
- Shaping and layout use font metrics and glyph IDs, never atlas placement.
- PixlText depends on PixlConcurrency; initial execution is one lane with later lane scaling kept internal.
- Hot text work uses contiguous, cache-aligned, data-oriented storage.
- Base GSUB lookup types 1–8, GPOS lookup types 1–9, and the GDEF data needed by lookup flags are implemented in platform-agnostic Swift.
- Hot GSUB/GPOS execution uses indexed immutable plans and noncopyable contiguous glyph buffers.
- Source `TextRun` records and output `GlyphRun` records are separate. Run execution borrows contiguous run and precompiled-plan columns through call-local spans and writes all results into shared reusable glyph/run buffers.
- Unicode 16.0 line-breaking classification writes sparse allowed/mandatory UTF-8 offsets into reusable caller-owned storage; prohibited boundaries are implicit.
- OpenType layout parsing and execution have been exercised against every supported installed font; HarfBuzz matches the current Latin OpenType reference cases.
- Embedded bitmap fonts are a first-class font capability, including legacy `bdat`/`bloc`, monochrome `EBDT`/`EBLC`, color `CBDT`/`CBLC`, and `sbix` strikes.

## Open Design Gates

- Standalone package/target structure and Pixl/PixlUI adapter boundaries.
- Script-specific shaping stages, per-glyph feature masks, language selection, and feature policy.
- Variable-font FeatureVariations/ItemVariationStore evaluation and size-specific Device adjustments.
- Optional future AAT `morx`/`kerx` support for fonts whose advanced shaping is not expressed through OpenType Layout.
- Exact low-level line and paragraph records.
- Bidirectional and Unicode line-breaking implementation boundaries.
- Rasterisation and MSDF-generation implementation.
- Bitmap-strike parsing, pixel-size selection, metrics, and glyph-image extraction.
- Cache ownership, keys, invalidation, and storage lifetime.
- Paragraph and run scheduling thresholds.
- Renderer primitive format, culling contract, and CPU/GPU integration seams.
- Mid-level abstraction scope and sequencing.

# Text Engine Roadmap

## Direction

Build a cross-platform text engine that is usable independently of Pixl. Pixl and PixlUI are clients of the engine, not its defining boundary.

Keep text layout and glyph/atlas work separate from renderer lowering. The engine should eventually produce ordered, pre-culled renderer primitives that make GPU and CPU integration straightforward for Pixl, other engines, and applications.

Start with efficient low-level data and algorithms. Add mid-level, TextKit 2-like abstractions only when they can be built cleanly on those primitives with measured overhead.

The final package name and target boundaries remain open.

## Current Focus

1. Define the low-level paragraph input and output records over positioned lines.
2. Establish paragraph boundaries, spacing, and geometry without changing line-local positioning.
3. Validate multiple paragraphs visually using the existing full-layout playground.
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
- Unicode no-break controls are authoritative: word joiner, non-breaking space, and non-breaking hyphen suppress opportunities across their protected boundaries. Future automatic hyphenation must preserve them.
- Line-breaking opportunities are visually validated with long text and an explicit mandatory break in the playground.
- Single-line composition selects the last fitting legal opportunity without splitting glyph clusters. Its compact record separates consumed and visible ranges, references reusable contiguous position storage, preserves unbreakable overflow, and reports line metrics plus typographic and render bounds.
- Single-line composition is visually validated across shaped text: trailing whitespace is consumed but excluded from visible width, and the selected line remains within the available width.
- Mixed-run natural line geometry takes the maximum per-run above/below contribution during the existing scan. Associated-value line-height policies resolve a separate line box symmetrically around those natural extents; line spacing remains external.
- A `1.35×` line-height policy is visually validated: natural height `30.4`, resolved height `41.04`, and baseline offset `29.32` confirm equal half-leading distribution.
- Line composition resumes through a compact value containing source, glyph, run, opportunity, and unit indices. Shared shaped input is validated once; each later line starts directly at the prior line's returned indices without rescanning earlier content.
- The playground validates consecutive resumed-line boundaries with baseline-local glyph geometry. Consumed trailing break whitespace and glyph render overhang remain visible as distinct geometry outside the yellow visible-advance line box; neither changes wrapping width.
- Full composition runs until source exhaustion with no implicit line cap. `LineLayoutWorkspace` retains positioned glyphs and line records as two reusable contiguous columns; each line references its position range and stores its document-space baseline.
- Explicit line spacing affects only vertical stacking. It does not mutate baseline-local glyph positions, natural metrics, or resolved line height.
- PixlText now has exactly three stage workspaces: shaping, line breaking, and line layout. Typed buffers remain single contiguous columns; per-run shaping temporaries are `ShapingScratch`, while `Storage` remains reserved for long-lived retained identity.
- Future API vocabulary treats `Element` as a source-addressable content unit, `Paragraph` as the standard text element, and `Line` as derived layout referencing positioned glyph ranges. These abstractions retain efficient direct access to contiguous glyph/range data instead of fully hiding glyphs as TextKit 2 does. Line-break segments are not elements; attachments remain uncommitted.
- OpenType layout parsing and execution have been exercised against every supported installed font; HarfBuzz matches the current Latin OpenType reference cases.
- Embedded bitmap fonts are a first-class font capability, including legacy `bdat`/`bloc`, monochrome `EBDT`/`EBLC`, color `CBDT`/`CBLC`, and `sbix` strikes.

## Open Design Gates

- Standalone package/target structure and Pixl/PixlUI adapter boundaries.
- Script-specific shaping stages, per-glyph feature masks, language selection, and feature policy.
- Variable-font FeatureVariations/ItemVariationStore evaluation and size-specific Device adjustments.
- Optional future AAT `morx`/`kerx` support for fonts whose advanced shaping is not expressed through OpenType Layout.
- Exact low-level line and paragraph records.
- Language-aware automatic hyphenation, discretionary break insertion, and explicit no-wrap/no-hyphenation source ranges.
- Bidirectional implementation boundary.
- Rasterisation and MSDF-generation implementation.
- Bitmap-strike parsing, pixel-size selection, metrics, and glyph-image extraction.
- Cache ownership, keys, invalidation, and storage lifetime.
- Paragraph and run scheduling thresholds.
- Renderer primitive format, culling contract, and CPU/GPU integration seams.
- Mid-level abstraction scope and sequencing.

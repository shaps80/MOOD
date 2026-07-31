# PixlText Roadmap

## Current Slice

1. Introduce viewport-driven non-contiguous paragraph layout.
2. Add overscan, estimated offscreen geometry, and reuse of unchanged paragraph results.

## Completed Foundation

- Real SFNT registration, metrics, cmap, glyph advances, TrueType bounds, and installed-font probing.
- Platform-independent Unicode 16 NFC, Script data, and UAX #14 line opportunities.
- Data-oriented shaping with flat indexed GSUB/GPOS/GDEF plans and reusable caller-owned buffers.
- Source/glyph cluster mapping, mixed-font runs, positioning, typographic/render bounds.
- Required base-font layout input with internally resolved sparse range overrides.
- Resumable single-line composition and uncapped full multi-line composition.
- Natural/custom line height, independent line spacing, baseline-local positions, document baselines.
- Paragraph grouping, spacing, source/line ranges, bounds, render bounds, and first/last baselines.
- One borrowed `ParagraphStyle` per source paragraph, with leading/center/trailing alignment, logical-edge first-line indentation, leading/trailing indentation, and before/after/line spacing.
- Alignment retains baseline-local glyph positions and stores one horizontal origin per line.
- `LayoutConstraints`, `LineLimit`, and `Overflow` values; maximum line count stops composition cleanly and returns complete/overflow status.
- Minimum-line reservation derives overall geometry from base-font metrics without synthetic content or line records; empty source retains one base-font insertion line.
- `DefaultLineMetrics` selects automatic base-font or inherited final-line geometry for otherwise metric-less lines.
- Cluster-safe trailing ellipsis reserves its exact shaped advance, supports narrow widths, and emits generated insertion records without changing source ranges.
- Soft and automatic English hyphenation insert shaped hyphen glyphs only when their chosen break is used. Portable checked-in pattern/exception data requires no platform dependency.
- Exactly three reusable stage workspaces; paragraph records are another line-layout column, not another workspace.
- Playground validation for shaping, break opportunities, words, lines, paragraphs, generated insertions, per-paragraph styling, capped/unlimited layout, safe line-limit clamping, minimum-line geometry, and automatic/inherited default metrics.
- TrueType variable-font axes and named instances, clamped/normalized/`avar`-remapped coordinates, and descriptor axis selection.
- `gvar` interpolation for simple and composite outlines; HVAR/VVAR/MVAR metrics; GSUB/GPOS FeatureVariations; GDEF/GPOS VariationIndex adjustments.
- San Francisco variable-font validation across extreme weights, including changed advances and render geometry. Playground axis sliders drive each paragraph independently.

## Next Core Work

- Additional language hyphenation policy/data and explicit no-wrap/no-hyphen source ranges.
- Viewport-driven non-contiguous paragraph layout with overscan, estimated offscreen geometry, and reuse of unchanged paragraph results.
- Promote the stable low-level records into public `Element`, `Paragraph`, and `Line` APIs without hiding contiguous glyph/range access.
- Rasterisation/MSDF generation, dynamic atlas packing, cache ownership and lifetime.
- Ordered renderer-neutral primitives containing pre-culled positioned glyph data and atlas references.

## Later Systems

- Head and middle truncation modes.
- CFF/CFF2 outline parsing and variable outline imaging; the current outline path is TrueType `glyf`/`gvar`.
- Embedded bitmap-strike parsing, selection, metrics, and extraction.
- Bidirectional resolution and script-specific shaping/reordering/feature masks.
- Higher-level editing/navigation APIs, including glyph-aware source selections, caret geometry, and hit testing.

## Open Gates

- Exact bidi and script-shaping boundaries.
- Hyphenation language source and policy beyond the current English fallback.
- Overflow/truncation semantics across mixed styles.
- Bitmap/vector/color glyph capability model.
- Cache keys, invalidation, and scheduling thresholds.
- Standalone package boundaries and final public API surface.

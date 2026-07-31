# PixlText Roadmap

## Current Slice

1. Add `ParagraphStyle` value types: `TextAlignment`, `Indentation`, `Spacing`, and `Hyphenation`.
2. Apply alignment and indentation while preserving baseline-local glyph positions.
3. Expose paragraph-style geometry in the playground for visual validation.

## Completed Foundation

- Real SFNT registration, metrics, cmap, glyph advances, TrueType bounds, and installed-font probing.
- Platform-independent Unicode 16 NFC, Script data, and UAX #14 line opportunities.
- Data-oriented shaping with flat indexed GSUB/GPOS/GDEF plans and reusable caller-owned buffers.
- Source/glyph cluster mapping, mixed-font runs, positioning, typographic/render bounds.
- Resumable single-line composition and uncapped full multi-line composition.
- Natural/custom line height, independent line spacing, baseline-local positions, document baselines.
- Paragraph grouping, spacing, source/line ranges, bounds, render bounds, and first/last baselines.
- Exactly three reusable stage workspaces; paragraph records are another line-layout column, not another workspace.
- Playground validation for shaping, break opportunities, words, lines, and multiple paragraphs.

## Next Core Work

- `LayoutConstraints`, `LineLimit`, and `Overflow` including cluster-safe head/middle/tail truncation.
- Reserved minimum-line height without synthetic line records.
- Automatic language-aware hyphenation; explicit no-wrap/no-hyphen source ranges.
- Bidirectional resolution and script-specific shaping/reordering/feature masks.
- Variable-font FeatureVariations/ItemVariationStore and Device adjustments.

## Later Systems

- Embedded bitmap-strike parsing, selection, metrics, and extraction.
- Rasterisation/MSDF generation, dynamic atlas packing, cache ownership and lifetime.
- Low-level paragraph/content records evolving into `Element`, `Paragraph`, and `Line` APIs.
- Ordered renderer-neutral primitives, viewport layout/culling, and higher-level editing/navigation APIs.

## Open Gates

- Exact bidi and script-shaping boundaries.
- Hyphenation language source and policy.
- Overflow/truncation semantics across mixed styles.
- Bitmap/vector/color glyph capability model.
- Cache keys, invalidation, and scheduling thresholds.
- Standalone package boundaries and final public API surface.

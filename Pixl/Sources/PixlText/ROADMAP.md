# PixlText Roadmap

## Current Slice

1. Visually validate unlimited/capped layout and complete/overflow status.
2. Implement reserved minimum-line height.
3. Implement cluster-safe trailing ellipsis with reserved shaped-token advance.

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
- Exactly three reusable stage workspaces; paragraph records are another line-layout column, not another workspace.
- Playground validation for shaping, break opportunities, words, lines, multiple paragraphs, and tap-selected per-paragraph styling.

## Next Core Work

- First `Overflow` implementation after reserved minimum-line height: cluster-safe trailing ellipsis with reserved shaped-token advance.
- Reserved minimum-line height without synthetic line records.
- Automatic language-aware hyphenation; explicit no-wrap/no-hyphen source ranges.
- Bidirectional resolution and script-specific shaping/reordering/feature masks.
- Variable-font FeatureVariations/ItemVariationStore and Device adjustments.

## Later Systems

- Head and middle truncation modes.
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

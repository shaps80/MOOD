import SwiftUI
import PixlText

struct ShapingView: View {
    private struct Row: Identifiable {
        let id: Int
        let info: Font.ShapingDebugInfo
    }

    private static let text = "Hello, world!"
    private let rows: Result<[Row], Error>

    init(font: PlaygroundFont) {
        rows = Result {
            let bytes = try font.loadBytes()
            let information = try Font.system(size: 48).shapingDebugInfo(
                in: Self.text,
                fontBytes: bytes,
                fontID: font.path
            )
            var rows: [Row] = []
            for (index, info) in information.enumerated() {
                rows.append(.init(id: index, info: info))
            }
            return rows
        }
    }

    var body: some View {
        ScrollView {
            switch rows {
            case .success(let rows):
                Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 12) {
                    GridRow {
                        header("Source")
                        header("Normalized")
                        header("Before")
                        header("After")
                        header("Position")
                        header("Rule")
                    }

                    Divider()
                        .gridCellColumns(6)

                    ForEach(rows, id: \ShapingView.Row.id) { row in
                        ShapingGridRow(info: row.info)
                    }
                }
                .padding(24)

            case .failure(let error):
                ContentUnavailableView(
                    "Shaping failed",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
                .foregroundStyle(.red)
            }
        }
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

}

private struct ShapingGridRow: View {
    let info: Font.ShapingDebugInfo

    var body: some View {
        GridRow {
            Text(info.source)
                .font(.title2)
            Text(scalars(info.normalizedScalars))
                .monospaced()
            Text(glyphs(info.nominalGlyphIDs))
                .monospacedDigit()
            Text(glyphs(info.shapedGlyphIDs))
                .monospacedDigit()
                .foregroundStyle(info.nominalGlyphIDs == info.shapedGlyphIDs ? Color.gray : Color.yellow)
            Text(position(info))
                .monospacedDigit()
                .foregroundStyle(hasPositioning(info) ? Color.yellow : Color.gray)
            Text(rule(info))
                .foregroundStyle(info.lookupIndex == nil ? Color.gray : Color.primary)
        }
    }

    private func scalars(_ values: [Unicode.Scalar]) -> String {
        values.map { "U+" + String($0.value, radix: 16, uppercase: true) }
            .joined(separator: " ")
    }

    private func glyphs(_ values: [UInt16]) -> String {
        values.map(String.init).joined(separator: ", ")
    }

    private func rule(_ info: Font.ShapingDebugInfo) -> String {
        guard let feature = info.feature, let lookup = info.lookupIndex else { return "—" }
        return "\(feature) · lookup \(lookup)"
    }

    private func hasPositioning(_ info: Font.ShapingDebugInfo) -> Bool {
        info.xPlacement != 0 || info.yPlacement != 0
            || info.xAdvance != 0 || info.yAdvance != 0
    }

    private func position(_ info: Font.ShapingDebugInfo) -> String {
        guard hasPositioning(info) else { return "—" }
        return "place(\(info.xPlacement), \(info.yPlacement)) advance(\(info.xAdvance), \(info.yAdvance))"
    }
}

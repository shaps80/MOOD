import PixlGraphics
import Swift

/// A regular row-major grid of equally sized texture regions.
public struct SpriteSheet {
    public let asset: TextureAsset
    public let columns: Int
    public let rows: Int
    public let regions: [TextureRegion]

    public init(asset: TextureAsset, columns: Int, rows: Int) {
        precondition(columns > 0 && rows > 0, "Sprite sheet grid must be nonempty")
        precondition(
            asset.size.x.isMultiple(of: columns),
            "Sprite sheet width must divide evenly into columns"
        )
        precondition(
            asset.size.y.isMultiple(of: rows),
            "Sprite sheet height must divide evenly into rows"
        )

        self.asset = asset
        self.columns = columns
        self.rows = rows

        let frameWidth = asset.size.x / columns
        let frameHeight = asset.size.y / rows
        var regions: [TextureRegion] = []
        regions.reserveCapacity(columns * rows)

        for row in 0..<rows {
            for column in 0..<columns {
                regions.append(
                    TextureRegion(
                        asset: asset,
                        source: Rect(
                            x: Double(column * frameWidth),
                            y: Double(row * frameHeight),
                            width: Double(frameWidth),
                            height: Double(frameHeight)
                        )
                    )
                )
            }
        }

        self.regions = regions
    }

    public func region(column: Int, row: Int) -> TextureRegion {
        precondition((0..<columns).contains(column), "Sprite sheet column is out of bounds")
        precondition((0..<rows).contains(row), "Sprite sheet row is out of bounds")
        return regions[(row * columns) + column]
    }

    public subscript<Columns: RangeExpression>(
        row row: Int,
        columns columns: Columns
    ) -> [TextureRegion] where Columns.Bound == Int {
        precondition((0..<rows).contains(row), "Sprite sheet row is out of bounds")
        let columns = columns.relative(to: 0..<self.columns)
        precondition(
            columns.lowerBound >= 0 && columns.upperBound <= self.columns,
            "Sprite sheet column range is out of bounds"
        )
        return columns.map { region(column: $0, row: row) }
    }

    public subscript(row row: Int) -> [TextureRegion] {
        self[row: row, columns: 0...]
    }

    public subscript<Rows: RangeExpression>(
        column column: Int,
        rows rows: Rows
    ) -> [TextureRegion] where Rows.Bound == Int {
        precondition(
            (0..<columns).contains(column),
            "Sprite sheet column is out of bounds"
        )
        let rows = rows.relative(to: 0..<self.rows)
        precondition(
            rows.lowerBound >= 0 && rows.upperBound <= self.rows,
            "Sprite sheet row range is out of bounds"
        )
        return rows.map { region(column: column, row: $0) }
    }

    public subscript(column column: Int) -> [TextureRegion] {
        self[column: column, rows: 0...]
    }
}

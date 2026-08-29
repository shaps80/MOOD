import PixlGraphics
import Swift

/// A regular row-major grid of equally sized texture regions.
public struct SpriteSheet {
    /// Texture asset divided by the sheet.
    public let asset: TextureAsset
    /// Number of equal-width columns.
    public let columns: Int
    /// Number of equal-height rows.
    public let rows: Int
    /// Every region in row-major order.
    public let regions: [TextureRegion]

    /// Divides a texture asset into a regular grid.
    ///
    /// ```swift
    /// let sheet = SpriteSheet(asset: playerTexture, columns: 4, rows: 2)
    /// let idle = sheet.region(column: 0, row: 0)
    /// ```
    ///
    /// - Parameters:
    ///   - asset: Texture asset containing the grid.
    ///   - columns: Positive column count that evenly divides the texture width.
    ///   - rows: Positive row count that evenly divides the texture height.
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
                            x: Float(column * frameWidth),
                            y: Float(row * frameHeight),
                            width: Float(frameWidth),
                            height: Float(frameHeight)
                        )
                    )
                )
            }
        }

        self.regions = regions
    }

    /// Returns one region by its zero-based grid coordinates.
    /// - Parameters:
    ///   - column: Zero-based column index.
    ///   - row: Zero-based row index.
    /// - Returns: The region at `column` and `row`.
    public func region(column: Int, row: Int) -> TextureRegion {
        precondition((0..<columns).contains(column), "Sprite sheet column is out of bounds")
        precondition((0..<rows).contains(row), "Sprite sheet row is out of bounds")
        return regions[(row * columns) + column]
    }

    /// Returns selected columns from one row.
    /// - Parameters:
    ///   - row: Zero-based row index.
    ///   - columns: Column range to return.
    /// - Returns: Regions ordered from the range's lower to upper bound.
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

    /// Returns every region in one row.
    /// - Parameter row: Zero-based row index.
    /// - Returns: The row's regions from left to right.
    public subscript(row row: Int) -> [TextureRegion] {
        self[row: row, columns: 0...]
    }

    /// Returns selected rows from one column.
    /// - Parameters:
    ///   - column: Zero-based column index.
    ///   - rows: Row range to return.
    /// - Returns: Regions ordered from the range's lower to upper bound.
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

    /// Returns every region in one column.
    /// - Parameter column: Zero-based column index.
    /// - Returns: The column's regions from top to bottom.
    public subscript(column column: Int) -> [TextureRegion] {
        self[column: column, rows: 0...]
    }
}

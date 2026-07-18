import Pixl2D
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
            asset.size.width.isMultiple(of: columns),
            "Sprite sheet width must divide evenly into columns"
        )
        precondition(
            asset.size.height.isMultiple(of: rows),
            "Sprite sheet height must divide evenly into rows"
        )

        self.asset = asset
        self.columns = columns
        self.rows = rows

        let frameWidth = asset.size.width / columns
        let frameHeight = asset.size.height / rows
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
}

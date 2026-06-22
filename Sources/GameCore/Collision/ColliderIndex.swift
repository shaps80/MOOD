import Swift

extension Tilemap {
    /// Collision-facing view of a tilemap.
    var colliderIndex: ColliderIndex {
        ColliderIndex(tilemap: self)
    }

    /// Collision-facing view of a tilemap.
    ///
    /// The tilemap stores authored tile data. The collider index answers the
    /// collision-specific question:
    ///
    /// ```text
    /// Which tile colliders could intersect this world-space rect?
    /// ```
    ///
    /// Today this is a lightweight wrapper around the tile grid. Later this can
    /// cache collider cells, merge adjacent wall colliders, or apply layer/mask
    /// filtering without moving that responsibility into `Tilemap`.
    ///
    /// Example with 16x16 tiles:
    ///
    /// ```text
    /// Proposed world-space collider bounds:
    ///
    ///   minX = 18, maxX = 49
    ///   minY = 20, maxY = 51
    ///
    /// Tile coordinates touched:
    ///
    ///   columns = 1...3
    ///   rows    = 1...3
    ///
    /// Grid:
    ///
    ///      0    1    2    3
    ///   +----+----+----+----+
    /// 0 |    |    |    |    |
    ///   +----+----+----+----+
    /// 1 |    | XX | XX | XX |
    ///   +----+----+----+----+
    /// 2 |    | XX | XX | XX |
    ///   +----+----+----+----+
    /// 3 |    | XX | XX | XX |
    ///   +----+----+----+----+
    ///
    /// Only the marked cells are inspected. If any of those tiles have a
    /// collider, the index converts that tile-local collider into world-space
    /// bounds before passing it to the collision resolver.
    /// ```
    struct ColliderIndex: Sendable {
        private let tilemap: Tilemap

        init(tilemap: Tilemap) {
            self.tilemap = tilemap
        }

        /// Visits colliders in tile cells touched by `bounds`.
        ///
        /// This is the broad phase for tile collision:
        ///
        /// ```text
        /// world rect -> tile coordinate range -> only those cells
        /// ```
        ///
        /// For a 32x32 player and 16x16 tiles, this usually checks around
        /// 4-9 cells instead of every tile in the map.
        func forEach(intersecting bounds: Rect, _ body: (Collider) -> Void) {
            guard let range = tilemap.tileRange(intersecting: bounds) else {
                return
            }

            for y in range.rows {
                for x in range.columns {
                    guard let tile = tilemap.tile(x: x, y: y),
                          let collider = tile.collider
                    else {
                        continue
                    }

                    body(
                        Collider(
                            bounds: collider.worldBounds(
                                at: Vec2(
                                    x: Double(x) * tilemap.tileSize.x,
                                    y: Double(y) * tilemap.tileSize.y
                                )
                            )
                        )
                    )
                }
            }
        }
    }
}

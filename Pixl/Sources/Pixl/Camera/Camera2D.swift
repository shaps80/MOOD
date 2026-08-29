import Pixl2D

/// A camera that produces a finite, invertible affine world-to-clip projection.
public protocol Camera2D: Camera where Projection == Transform2D {}

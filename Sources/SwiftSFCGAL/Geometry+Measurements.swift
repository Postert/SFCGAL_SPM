#if canImport(CSFCGAL_System)
import CSFCGAL_System
#elseif canImport(CSFCGAL_Binary)
import CSFCGAL_Binary
#endif
import CSFCGAL_Shim

extension Geometry {

    // MARK: - Area

    /// Returns the 2D area of this geometry.
    ///
    /// Meaningful for `Polygon`, `MultiPolygon`, `GeometryCollection`, and
    /// surfaces.  Points and linestrings have area 0.
    ///
    /// - Throws: `SFCGALError.operationFailed` if the geometry is invalid or the
    ///           operation is not supported for this type.
    public func area() throws -> Double {
        try sfcgalCall { sfcgal_geometry_area(handle) }
    }

    /// Returns the 3D area of this geometry.
    ///
    /// Unlike `area()`, the 3D variant accounts for tilt: a polygon that is
    /// inclined relative to the XY plane will have a larger 3D area than its
    /// 2D footprint.  Useful for computing the true surface area of building
    /// facades and sloped roofs.
    ///
    /// - Throws: `SFCGALError.operationFailed` if the geometry is invalid.
    public func area3D() throws -> Double {
        try sfcgalCall { sfcgal_geometry_area_3d(handle) }
    }

    // MARK: - Volume

    /// Returns the 3D volume enclosed by this geometry.
    ///
    /// Only meaningful for `Solid` geometries — the solid must be closed
    /// (every edge shared by exactly two faces).  All other geometry types
    /// return 0.
    ///
    /// - Throws: `SFCGALError.operationFailed` if the solid is not closed or
    ///           the geometry is otherwise invalid.
    public func volume() throws -> Double {
        try sfcgalCall { sfcgal_geometry_volume(handle) }
    }

    // MARK: - Length

    /// Returns the 2D length of this geometry.
    ///
    /// Meaningful for `LineString`, `MultiLineString`, and
    /// `GeometryCollection`.  Polygons and points have length 0.
    ///
    /// - Throws: `SFCGALError.operationFailed` if the geometry is invalid.
    public func length() throws -> Double {
        try sfcgalCall { sfcgal_geometry_length(handle) }
    }

    /// Returns the 3D length of this geometry, accounting for the Z coordinate.
    ///
    /// A diagonal line from `(0,0,0)` to `(1,1,1)` has 3D length √3 ≈ 1.732,
    /// but a 2D length of √2 ≈ 1.414 (ignoring Z).
    ///
    /// - Throws: `SFCGALError.operationFailed` if the geometry is invalid.
    public func length3D() throws -> Double {
        try sfcgalCall { sfcgal_geometry_length_3d(handle) }
    }

    // MARK: - Distance

    /// Returns the shortest 2D distance between this geometry and `other`.
    ///
    /// Returns 0 if the geometries intersect.
    ///
    /// - Throws: `SFCGALError.operationFailed` if either geometry is invalid.
    public func distance(to other: Geometry) throws -> Double {
        try sfcgalCall { sfcgal_geometry_distance(handle, other.handle) }
    }

    /// Returns the shortest 3D distance between this geometry and `other`.
    ///
    /// Two geometries that overlap in plan view but sit at different elevations
    /// will have a non-zero 3D distance.
    ///
    /// - Throws: `SFCGALError.operationFailed` if either geometry is invalid.
    public func distance3D(to other: Geometry) throws -> Double {
        try sfcgalCall { sfcgal_geometry_distance_3d(handle, other.handle) }
    }
}

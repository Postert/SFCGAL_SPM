#if canImport(CSFCGAL_System)
import CSFCGAL_System
#elseif canImport(CSFCGAL_Binary)
import CSFCGAL_Binary
#endif
import CSFCGAL_Shim

// MARK: - Polygon orientation

/// The winding order of a polygon's exterior ring.
///
/// SFCGAL follows the mathematical convention where Y increases upward:
/// - **Counter-clockwise** is the standard OGC exterior-ring orientation.
/// - **Clockwise** is the standard OGC interior-ring (hole) orientation.
public enum PolygonOrientation {
    /// Counter-clockwise winding — the standard exterior ring orientation (OGC/ISO).
    case counterClockwise
    /// Clockwise winding — the standard interior (hole) ring orientation.
    case clockwise
    /// SFCGAL could not determine the orientation (geometry is invalid or degenerate).
    case undetermined
}

// MARK: - Spatial predicates

extension Geometry {

    // ── Binary predicates (two-geometry) ─────────────────────────────────────

    /// Returns `true` if this geometry and `other` share at least one point in 2D.
    ///
    /// - Throws: `SFCGALError.operationFailed` if either geometry is invalid.
    public func intersects(_ other: Geometry) throws -> Bool {
        let r: Int32 = try sfcgalCall { sfcgal_geometry_intersects(handle, other.handle) }
        return r != 0
    }

    /// Returns `true` if this geometry and `other` share at least one point in 3D.
    ///
    /// Unlike `intersects(_:)`, the Z coordinate is taken into account — two
    /// geometries that overlap in plan view but occupy different elevations are
    /// not considered to intersect.
    ///
    /// - Throws: `SFCGALError.operationFailed` if either geometry is invalid.
    public func intersects3D(_ other: Geometry) throws -> Bool {
        let r: Int32 = try sfcgalCall { sfcgal_geometry_intersects_3d(handle, other.handle) }
        return r != 0
    }

    /// Returns `true` if every point of `other` lies within or on the boundary
    /// of this geometry (2D).
    ///
    /// `covers` is like `contains` but handles the boundary correctly: a polygon
    /// covers a point on its ring, whereas OGC `contains` does not.
    ///
    /// - Throws: `SFCGALError.operationFailed` if either geometry is invalid.
    public func covers(_ other: Geometry) throws -> Bool {
        let r: Int32 = try sfcgalCall { sfcgal_geometry_covers(handle, other.handle) }
        return r != 0
    }

    /// Returns `true` if every point of `other` lies within or on the boundary
    /// of this geometry, considering all three dimensions.
    ///
    /// - Throws: `SFCGALError.operationFailed` if either geometry is invalid.
    public func covers3D(_ other: Geometry) throws -> Bool {
        let r: Int32 = try sfcgalCall { sfcgal_geometry_covers_3d(handle, other.handle) }
        return r != 0
    }

    // ── Unary predicates (single-geometry) ───────────────────────────────────

    /// Returns `true` if this geometry is planar (lies in a single plane).
    ///
    /// All 2D geometries are trivially planar. For 3D surfaces this checks
    /// whether all points share a common plane — useful for validating
    /// `PolyhedralSurface` patches before computing 3D area.
    ///
    /// - Throws: `SFCGALError.operationFailed` if the geometry is invalid.
    public func isPlanar() throws -> Bool {
        let r: Int32 = try sfcgalCall { sfcgal_geometry_is_planar(handle) }
        return r != 0
    }

    /// Returns the winding order of this polygon's exterior ring.
    ///
    /// - Precondition: `self` must be a `Polygon` and must be valid.
    /// - Throws: `SFCGALError.operationFailed` if the geometry is not a valid polygon.
    public func orientation() throws -> PolygonOrientation {
        let r: Int32 = try sfcgalCall { sfcgal_geometry_orientation(handle) }
        switch r {
        case -1: return .counterClockwise
        case  1: return .clockwise
        default: return .undetermined
        }
    }
}

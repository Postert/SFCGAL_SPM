#if canImport(CSFCGAL_System)
import CSFCGAL_System
#elseif canImport(CSFCGAL_Binary)
import CSFCGAL_Binary
#endif
import CSFCGAL_Shim

// MARK: - Validation result

/// The result of a detailed geometry validity check.
///
/// Returned by `Geometry.validationResult()`. When a geometry is invalid,
/// `reason` contains a human-readable explanation and `location` (if SFCGAL
/// can determine it) is a geometry marking the exact problem site — e.g. the
/// self-intersection point of a ring.
public struct ValidationResult {
    /// Whether the geometry is valid.
    public let isValid: Bool
    /// Human-readable description of the invalidity, or `nil` if the geometry is valid.
    public let reason: String?
    /// A geometry marking the location of the invalidity (e.g. a `Point` at the
    /// self-intersection), or `nil` if valid or if SFCGAL could not localise the problem.
    public let location: Geometry?
}

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

    /// Returns a detailed validity report for this geometry.
    ///
    /// Unlike `isValid` (which only returns a `Bool`), this method also provides
    /// the reason for invalidity and, when SFCGAL can determine it, a geometry
    /// marking the exact location of the problem (e.g. a self-intersection point).
    ///
    /// This does **not** go through `sfcgalCall` because `sfcgal_geometry_is_valid_detail`
    /// communicates its result through its return value and out-parameters — not
    /// through the SFCGAL error handler.
    ///
    /// - Returns: A `ValidationResult` with validity flag, optional reason string,
    ///            and optional location geometry.
    public func validationResult() -> ValidationResult {
        var reasonPtr: UnsafeMutablePointer<CChar>? = nil
        // invalidity_location is sfcgal_geometry_t** → UnsafeMutablePointer<UnsafeMutableRawPointer?>
        var locationPtr: UnsafeMutableRawPointer? = nil
        let valid = sfcgal_geometry_is_valid_detail(handle, &reasonPtr, &locationPtr)

        let reason: String?
        if let r = reasonPtr {
            reason = String(cString: r)
            sfcgal_swift_free_buffer(r)
        } else {
            reason = nil
        }

        let location: Geometry?
        if let loc = locationPtr {
            // makeGeometry takes ownership — it will free loc in its deinit.
            location = makeGeometry(handle: loc, ownsHandle: true)
        } else {
            location = nil
        }

        return ValidationResult(isValid: valid != 0, reason: reason, location: location)
    }

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

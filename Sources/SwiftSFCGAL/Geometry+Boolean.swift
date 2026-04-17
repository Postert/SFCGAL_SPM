#if canImport(CSFCGAL_System)
import CSFCGAL_System
#elseif canImport(CSFCGAL_Binary)
import CSFCGAL_Binary
#endif
import CSFCGAL_Shim

// MARK: - Boolean set operations

extension Geometry {

    // ── 2D Boolean operations ─────────────────────────────────────────────────

    /// Returns the 2D intersection of this geometry and `other`.
    ///
    /// The intersection is the region shared by **both** geometries. If the
    /// geometries do not overlap the result is an empty geometry (e.g. an empty
    /// `GeometryCollection` or a degenerate point/line).
    ///
    /// The returned object is a new, fully owned geometry — modifying or
    /// releasing it has no effect on either input.
    ///
    /// - Throws: `SFCGALError.operationFailed` if the underlying C call fails
    ///           (e.g. degenerate input, unsupported geometry type).
    public func intersection(_ other: Geometry) throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_intersection(handle, other.handle)
        }) else {
            throw SFCGALError.operationFailed("intersection returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    /// Returns the 2D union of this geometry and `other`.
    ///
    /// The union is the region covered by **either** geometry — i.e. the merged
    /// shape. Overlapping areas appear only once in the result.
    ///
    /// - Throws: `SFCGALError.operationFailed` if the underlying C call fails.
    public func union(_ other: Geometry) throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_union(handle, other.handle)
        }) else {
            throw SFCGALError.operationFailed("union returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    /// Returns the 2D difference of this geometry minus `other`.
    ///
    /// The difference is the part of **this** geometry that does not overlap
    /// `other`. The operation is asymmetric: `A.difference(B) ≠ B.difference(A)`.
    ///
    /// - Throws: `SFCGALError.operationFailed` if the underlying C call fails.
    public func difference(_ other: Geometry) throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_difference(handle, other.handle)
        }) else {
            throw SFCGALError.operationFailed("difference returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    // ── 3D Boolean operations ─────────────────────────────────────────────────

    /// Returns the 3D intersection of this geometry and `other`.
    ///
    /// Unlike `intersection(_:)`, the Z coordinate is fully respected — two
    /// geometries that overlap in plan view but occupy different elevations
    /// produce an empty 3D intersection.
    ///
    /// > Note: 3D Boolean operations use CGAL's Nef polyhedra kernel, which is
    /// > GPL-licensed. See the package README's Licensing section for details.
    ///
    /// - Throws: `SFCGALError.operationFailed` if the underlying C call fails.
    public func intersection3D(_ other: Geometry) throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_intersection_3d(handle, other.handle)
        }) else {
            throw SFCGALError.operationFailed("intersection3D returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    /// Returns the 3D union of this geometry and `other`.
    ///
    /// > Note: 3D Boolean operations use CGAL's Nef polyhedra kernel, which is
    /// > GPL-licensed. See the package README's Licensing section for details.
    ///
    /// - Throws: `SFCGALError.operationFailed` if the underlying C call fails.
    public func union3D(_ other: Geometry) throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_union_3d(handle, other.handle)
        }) else {
            throw SFCGALError.operationFailed("union3D returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    /// Returns the 3D difference of this geometry minus `other`.
    ///
    /// The operation is asymmetric: `A.difference3D(B) ≠ B.difference3D(A)`.
    ///
    /// > Note: 3D Boolean operations use CGAL's Nef polyhedra kernel, which is
    /// > GPL-licensed. See the package README's Licensing section for details.
    ///
    /// - Throws: `SFCGALError.operationFailed` if the underlying C call fails.
    public func difference3D(_ other: Geometry) throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_difference_3d(handle, other.handle)
        }) else {
            throw SFCGALError.operationFailed("difference3D returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }
}

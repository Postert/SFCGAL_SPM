#if canImport(CSFCGAL_System)
import CSFCGAL_System
#elseif canImport(CSFCGAL_Binary)
import CSFCGAL_Binary
#endif
import CSFCGAL_Shim

// MARK: - Affine and extrusion transformations
//
// All methods here return a new, fully owned `Geometry` — the receiver is
// never mutated.  Every call routes through `sfcgalCall { ... }` so that
// SFCGAL errors surface as `SFCGALError.operationFailed`.
//
// Function map (SFCGAL 2.2.0 C API → Swift method):
//
//   sfcgal_geometry_translate_2d                    → translated(dx:dy:)
//   sfcgal_geometry_translate_3d                    → translated(dx:dy:dz:)
//   sfcgal_geometry_rotate                          → rotated(angle:)
//   sfcgal_geometry_rotate_2d                       → rotated2D(angle:cx:cy:)
//   sfcgal_geometry_rotate_3d                       → rotated3D(angle:axis:)
//   sfcgal_geometry_rotate_3d_around_center         → rotated3D(angle:axis:center:)
//   sfcgal_geometry_rotate_x                        → rotatedX(angle:)
//   sfcgal_geometry_rotate_y                        → rotatedY(angle:)
//   sfcgal_geometry_rotate_z                        → rotatedZ(angle:)
//   sfcgal_geometry_scale                           → scaled(factor:)
//   sfcgal_geometry_scale_3d                        → scaled(sx:sy:sz:)
//   sfcgal_geometry_scale_3d_around_center          → scaled(sx:sy:sz:center:)
//   sfcgal_geometry_extrude                         → extrude(dx:dy:dz:)
//   sfcgal_geometry_straight_skeleton               → straightSkeleton()
//   sfcgal_geometry_straight_skeleton_distance_in_m → straightSkeletonWithDistances()
//   sfcgal_geometry_extrude_straight_skeleton       → straightSkeletonExtrude(height:)
//   sfcgal_geometry_extrude_polygon_straight_skeleton
//                                                   → extrudePolygonStraightSkeleton(
//                                                        buildingHeight:roofHeight:)
//   sfcgal_geometry_straight_skeleton_partition     → straightSkeletonPartition(
//                                                        autoOrientation:)

extension Geometry {

    // ── Translation ───────────────────────────────────────────────────────────

    /// Returns a copy of this geometry translated by `(dx, dy)` in 2D.
    public func translated(dx: Double, dy: Double) throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_translate_2d(handle, dx, dy)
        }) else {
            throw SFCGALError.operationFailed("translate_2d returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    /// Returns a copy of this geometry translated by `(dx, dy, dz)` in 3D.
    public func translated(dx: Double, dy: Double, dz: Double) throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_translate_3d(handle, dx, dy, dz)
        }) else {
            throw SFCGALError.operationFailed("translate_3d returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    // ── Rotation ──────────────────────────────────────────────────────────────

    /// Returns a copy rotated by `angle` radians around the origin (2D).
    ///
    /// For 2D geometry this is equivalent to rotation around the Z axis through `(0,0)`.
    public func rotated(angle: Double) throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_rotate(handle, angle)
        }) else {
            throw SFCGALError.operationFailed("rotate returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    /// Returns a copy rotated by `angle` radians around the 2D point `(cx, cy)`.
    public func rotated2D(angle: Double, cx: Double, cy: Double) throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_rotate_2d(handle, angle, cx, cy)
        }) else {
            throw SFCGALError.operationFailed("rotate_2d returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    /// Returns a copy rotated by `angle` radians around the 3D axis vector `(ax, ay, az)`.
    ///
    /// The axis vector does not need to be normalised — SFCGAL handles that internally.
    public func rotated3D(angle: Double, ax: Double, ay: Double, az: Double) throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_rotate_3d(handle, angle, ax, ay, az)
        }) else {
            throw SFCGALError.operationFailed("rotate_3d returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    /// Returns a copy rotated by `angle` radians around the 3D axis `(ax, ay, az)`
    /// passing through the centre `(cx, cy, cz)`.
    public func rotated3D(angle: Double,
                          ax: Double, ay: Double, az: Double,
                          cx: Double, cy: Double, cz: Double) throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_rotate_3d_around_center(handle, angle, ax, ay, az, cx, cy, cz)
        }) else {
            throw SFCGALError.operationFailed("rotate_3d_around_center returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    /// Returns a copy rotated by `angle` radians around the X axis.
    public func rotatedX(angle: Double) throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_rotate_x(handle, angle)
        }) else {
            throw SFCGALError.operationFailed("rotate_x returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    /// Returns a copy rotated by `angle` radians around the Y axis.
    public func rotatedY(angle: Double) throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_rotate_y(handle, angle)
        }) else {
            throw SFCGALError.operationFailed("rotate_y returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    /// Returns a copy rotated by `angle` radians around the Z axis.
    public func rotatedZ(angle: Double) throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_rotate_z(handle, angle)
        }) else {
            throw SFCGALError.operationFailed("rotate_z returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    // ── Scale ─────────────────────────────────────────────────────────────────

    /// Returns a copy scaled uniformly by `factor` around the origin.
    ///
    /// Areas scale by `factor²`, volumes by `factor³`.
    public func scaled(factor: Double) throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_scale(handle, factor)
        }) else {
            throw SFCGALError.operationFailed("scale returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    /// Returns a copy scaled non-uniformly by `(sx, sy, sz)` around the origin.
    public func scaled(sx: Double, sy: Double, sz: Double) throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_scale_3d(handle, sx, sy, sz)
        }) else {
            throw SFCGALError.operationFailed("scale_3d returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    /// Returns a copy scaled non-uniformly by `(sx, sy, sz)` around the centre `(cx, cy, cz)`.
    public func scaled(sx: Double, sy: Double, sz: Double,
                       cx: Double, cy: Double, cz: Double) throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_scale_3d_around_center(handle, sx, sy, sz, cx, cy, cz)
        }) else {
            throw SFCGALError.operationFailed("scale_3d_around_center returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    // ── Extrusion ─────────────────────────────────────────────────────────────

    /// Extrudes a 2D geometry along the vector `(dx, dy, dz)` to produce a `Solid`.
    ///
    /// Foundation of the LOD1 CityGML pipeline: take a building footprint and
    /// extrude it straight up by the building's height to obtain a 3D solid.
    ///
    /// ```swift
    /// let footprint = try Geometry.fromWKT("POLYGON((0 0,10 0,10 5,0 5,0 0))")
    /// let building  = try footprint.extrude(dx: 0, dy: 0, dz: 12)  // 10×5×12 box
    /// ```
    ///
    /// - Throws: `SFCGALError.operationFailed` if the geometry cannot be extruded.
    public func extrude(dx: Double, dy: Double, dz: Double) throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_extrude(handle, dx, dy, dz)
        }) else {
            throw SFCGALError.operationFailed("extrude returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    // ── Straight skeleton ─────────────────────────────────────────────────────

    /// Returns the straight skeleton of this polygon as a `MultiLineString`.
    ///
    /// The straight skeleton is the geometric structure traced by inward-shrinking
    /// edges of the polygon — used for hipped-roof construction and inset offsets.
    public func straightSkeleton() throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_straight_skeleton(handle)
        }) else {
            throw SFCGALError.operationFailed("straight_skeleton returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    /// Returns the straight skeleton with per-segment distance metadata.
    ///
    /// Each output segment carries the distance from the original polygon edge,
    /// which is the value used for offsetting at a given inset depth.
    public func straightSkeletonWithDistances() throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_straight_skeleton_distance_in_m(handle)
        }) else {
            throw SFCGALError.operationFailed("straight_skeleton_distance_in_m returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    /// Extrudes the polygon using its straight skeleton to produce a hipped roof.
    ///
    /// `height` is the ridge height — the maximum elevation reached by the apex
    /// of the skeleton. Useful for LOD2 CityGML where roofs are derived from
    /// footprints automatically.
    public func straightSkeletonExtrude(height: Double) throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_extrude_straight_skeleton(handle, height)
        }) else {
            throw SFCGALError.operationFailed("extrude_straight_skeleton returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    /// Builds a complete hipped-roof building from a footprint polygon.
    ///
    /// - Parameters:
    ///   - buildingHeight: Height of the vertical walls (eaves elevation).
    ///   - roofHeight:    Additional height of the roof apex above the eaves.
    ///
    /// Total ridge elevation is `buildingHeight + roofHeight`. This is the
    /// one-shot LOD2 building generator: walls + hipped roof in a single solid.
    public func extrudePolygonStraightSkeleton(buildingHeight: Double,
                                               roofHeight: Double) throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_extrude_polygon_straight_skeleton(handle,
                                                              buildingHeight,
                                                              roofHeight)
        }) else {
            throw SFCGALError.operationFailed(
                "extrude_polygon_straight_skeleton returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    /// Partitions this polygon into simpler regions along its straight skeleton.
    ///
    /// - Parameter autoOrientation: If `true`, SFCGAL automatically corrects ring
    ///   orientation; if `false`, the input is used as-is and must already be valid.
    public func straightSkeletonPartition(autoOrientation: Bool = true) throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_straight_skeleton_partition(handle, autoOrientation)
        }) else {
            throw SFCGALError.operationFailed("straight_skeleton_partition returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }
}

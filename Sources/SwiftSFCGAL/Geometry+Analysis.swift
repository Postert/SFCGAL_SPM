#if canImport(CSFCGAL_System)
import CSFCGAL_System
#elseif canImport(CSFCGAL_Binary)
import CSFCGAL_Binary
#endif
import CSFCGAL_Shim

// MARK: - Analysis operations
//
// These functions take a geometry and return a NEW, fully owned `Geometry`
// describing some derived structural property — convex hull, medial axis,
// alpha shapes, convex partitions, etc.  All return values are wrapped with
// `ownsHandle: true` and routed through `sfcgalCall` for error handling.
//
// Function map (SFCGAL 2.2.0 C API → Swift method):
//
//   sfcgal_geometry_convexhull              → convexHull()
//   sfcgal_geometry_convexhull_3d           → convexHull3D()
//   sfcgal_geometry_approximate_medial_axis → approximateMedialAxis()
//   sfcgal_geometry_alpha_shapes            → alphaShapes(alpha:allowHoles:)
//   sfcgal_geometry_optimal_alpha_shapes    → optimalAlphaShapes(allowHoles:components:)
//   sfcgal_geometry_alpha_wrapping_3d       → alphaWrapping3D(relativeAlpha:relativeOffset:)
//   sfcgal_y_monotone_partition_2           → yMonotonePartition()
//   sfcgal_approx_convex_partition_2        → approximateConvexPartition()
//   sfcgal_greene_approx_convex_partition_2 → greeneConvexPartition()
//   sfcgal_optimal_convex_partition_2       → optimalConvexPartition()
//
// Already wrapped in earlier issues (kept here for cross-reference):
//   • `straightSkeleton()`            → Geometry+Transformations.swift  (#15)
//   • `straightSkeletonPartition(_:)` → Geometry+Transformations.swift  (#15)
//   • `validationResult()`            → Geometry+Predicates.swift       (#12)

extension Geometry {

    // ── Convex hull ───────────────────────────────────────────────────────────

    /// Returns the smallest 2D convex polygon containing every point of this geometry.
    ///
    /// For a polygon already convex, the hull is geometrically equivalent to the
    /// input.  For points, lines, or non-convex polygons, the hull is the
    /// "rubber band" outline — the tightest convex shape that encloses everything.
    ///
    /// - Throws: `SFCGALError.operationFailed` on degenerate input or internal failure.
    public func convexHull() throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_convexhull(handle)
        }) else {
            throw SFCGALError.operationFailed("convexhull returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    /// Returns the smallest 3D convex polyhedron containing every point of this geometry.
    ///
    /// Useful for bounding-volume queries, simplifying CityGML buildings into
    /// convex envelopes, and AR collision approximation.
    ///
    /// - Throws: `SFCGALError.operationFailed` on degenerate input or internal failure.
    public func convexHull3D() throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_convexhull_3d(handle)
        }) else {
            throw SFCGALError.operationFailed("convexhull_3d returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    // ── Medial axis ───────────────────────────────────────────────────────────

    /// Returns the approximate medial axis — the locus of points equidistant
    /// from at least two boundary points.
    ///
    /// Useful for extracting centerlines from polygon road footprints,
    /// thalwegs from river banks, or simplifying any "long thin" shape into
    /// a 1D representation.
    ///
    /// - Throws: `SFCGALError.operationFailed` on degenerate input.
    public func approximateMedialAxis() throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_approximate_medial_axis(handle)
        }) else {
            throw SFCGALError.operationFailed("approximate_medial_axis returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    // ── Alpha shapes ──────────────────────────────────────────────────────────
    //
    // PLATFORM GATE:  `sfcgal_geometry_alpha_shapes` and
    // `sfcgal_geometry_optimal_alpha_shapes` are wrapped in `#if !_MSC_VER`
    // inside `sfcgal_c.h` (lines 1395–1427) — they are NOT compiled into
    // SFCGAL on Windows MSVC builds.  The Swift wrappers below mirror that
    // platform constraint via `#if !os(Windows)`.
    //
    // Workaround: alpha_wrapping_3d (below) is NOT MSVC-gated and is available
    // on all platforms.  Convex hull also serves as a reasonable upper-bound
    // approximation when alpha shapes are unavailable.

    #if !os(Windows)
    /// Returns the alpha-shape of this geometry — a "concave hull" parameterised
    /// by `alpha`.
    ///
    /// As `alpha` approaches infinity, the alpha-shape converges to the convex
    /// hull.  Smaller `alpha` produces tighter outlines that follow concave
    /// features.  `alpha` is the maximum permissible disc radius for the
    /// interior empty-disc test.
    ///
    /// > Platform note: not available on Windows MSVC builds — SFCGAL excludes
    /// > `sfcgal_geometry_alpha_shapes` via `#if !_MSC_VER` in `sfcgal_c.h`.
    ///
    /// - Parameters:
    ///   - alpha: Maximum disc radius. Defaults to 1.0, matching
    ///     `SFCGAL::algorithm::alphaShapes`. Larger values produce fewer concavities.
    ///   - allowHoles: Whether the result may contain interior holes.
    /// - Throws: `SFCGALError.operationFailed` on degenerate input.
    public func alphaShapes(alpha: Double = 1.0, allowHoles: Bool = false) throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_alpha_shapes(handle, alpha, allowHoles)
        }) else {
            throw SFCGALError.operationFailed("alpha_shapes returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    /// Returns the **optimal** alpha-shape — SFCGAL automatically chooses the
    /// `alpha` value that produces a result with the requested number of
    /// connected components.
    ///
    /// > Platform note: not available on Windows MSVC builds — see `alphaShapes`.
    ///
    /// - Parameters:
    ///   - allowHoles:   Whether the result may contain interior holes.
    ///   - components:   Desired number of connected components in the output.
    /// - Throws: `SFCGALError.operationFailed` on degenerate input.
    public func optimalAlphaShapes(allowHoles: Bool = false,
                                   components: Int = 1) throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_optimal_alpha_shapes(handle, allowHoles, size_t(components))
        }) else {
            throw SFCGALError.operationFailed("optimal_alpha_shapes returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }
    #endif  // !os(Windows)

    /// Returns a watertight 3D alpha-wrapping of a point set or mesh.
    ///
    /// Both parameters are **relative** — divisors of the bounding-box diagonal,
    /// not absolute distances.  Larger values produce coarser wrappings.
    ///
    /// - Parameters:
    ///   - relativeAlpha:  Relative alpha (typical values: 10–300).
    ///   - relativeOffset: Relative offset distance. Defaults to 0, matching
    ///     `SFCGAL::algorithm::alphaWrapping3D`.
    /// - Throws: `SFCGALError.operationFailed` on degenerate input.
    public func alphaWrapping3D(relativeAlpha: Int,
                                relativeOffset: Int = 0) throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_geometry_alpha_wrapping_3d(handle,
                                              size_t(relativeAlpha),
                                              size_t(relativeOffset))
        }) else {
            throw SFCGALError.operationFailed("alpha_wrapping_3d returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    // ── Polygon partitions ────────────────────────────────────────────────────

    /// Partitions a simple polygon into y-monotone sub-polygons.
    ///
    /// Y-monotone polygons can be triangulated in linear time, so this is a
    /// standard preprocessing step for high-performance triangulation.
    ///
    /// - Throws: `SFCGALError.operationFailed` on degenerate input.
    public func yMonotonePartition() throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_y_monotone_partition_2(handle)
        }) else {
            throw SFCGALError.operationFailed("y_monotone_partition_2 returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    /// Partitions a simple polygon into convex pieces using an approximation
    /// algorithm (fast, near-optimal piece count).
    ///
    /// - Throws: `SFCGALError.operationFailed` on degenerate input.
    public func approximateConvexPartition() throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_approx_convex_partition_2(handle)
        }) else {
            throw SFCGALError.operationFailed("approx_convex_partition_2 returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    /// Partitions a simple polygon into convex pieces using Greene's algorithm.
    ///
    /// - Throws: `SFCGALError.operationFailed` on degenerate input.
    public func greeneConvexPartition() throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_greene_approx_convex_partition_2(handle)
        }) else {
            throw SFCGALError.operationFailed(
                "greene_approx_convex_partition_2 returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    /// Partitions a simple polygon into the **fewest possible** convex pieces.
    ///
    /// Optimal in the minimum-piece-count sense.  Slower than the approximate
    /// variants but produces fewer sub-polygons.
    ///
    /// - Throws: `SFCGALError.operationFailed` on degenerate input.
    public func optimalConvexPartition() throws -> Geometry {
        guard let ptr = try sfcgalCall({
            sfcgal_optimal_convex_partition_2(handle)
        }) else {
            throw SFCGALError.operationFailed("optimal_convex_partition_2 returned nil")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    // ── Validation detail (issue #16 sketch form) ─────────────────────────────

    /// Validates the geometry and returns `(isValid, reason)` — a convenience
    /// matching the signature sketched in Issue #16.
    ///
    /// For a richer result that also includes the location of the invalidity,
    /// use `validationResult()` (Issue #12, `Geometry+Predicates.swift`).
    public func validationDetail() -> (isValid: Bool, reason: String?) {
        let r = validationResult()
        return (r.isValid, r.reason)
    }
}

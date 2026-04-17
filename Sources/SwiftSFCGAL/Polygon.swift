#if canImport(CSFCGAL_System)
import CSFCGAL_System
#elseif canImport(CSFCGAL_Binary)
import CSFCGAL_Binary
#endif
import CSFCGAL_Shim

/// A planar polygon with an exterior ring and zero or more interior rings (holes).
///
/// Maps to SFCGAL's `POLYGON` type (type ID 3). The exterior ring is
/// counter-clockwise; interior rings (holes) are clockwise — the same winding
/// convention used by OGC WKT/WKB.
public class Polygon: Geometry {

    // MARK: - Initialisers

    /// Creates an empty polygon. Use `init(exteriorRing:)` for the common case.
    ///
    /// - Throws: `SFCGALError.operationFailed` if the C allocation fails.
    public convenience init() throws {
        guard let ptr = try sfcgalCall({ sfcgal_polygon_create() }) else {
            throw SFCGALError.operationFailed("Failed to create empty Polygon")
        }
        self.init(handle: ptr)
    }

    /// Creates a polygon from an exterior ring.
    ///
    /// SFCGAL takes ownership of a **clone** of `ring`; the original is unaffected.
    ///
    /// - Parameter ring: The exterior `LineString` ring.
    /// - Throws: `SFCGALError.operationFailed` if cloning or allocation fails.
    public convenience init(exteriorRing ring: LineString) throws {
        guard let cloned = sfcgal_geometry_clone(ring.handle) else {
            throw SFCGALError.operationFailed("Failed to clone exterior ring for Polygon")
        }
        guard let ptr = try sfcgalCall({ sfcgal_polygon_create_from_exterior_ring(cloned) }) else {
            sfcgal_geometry_delete(cloned)
            throw SFCGALError.operationFailed("Failed to create Polygon from exterior ring")
        }
        self.init(handle: ptr)
    }

    // MARK: - Ring access

    /// The exterior ring as a **borrowed** (non-owning) `LineString`.
    ///
    /// The returned ring is valid only while this `Polygon` is alive.
    public var exteriorRing: LineString {
        let ptr = sfcgal_polygon_exterior_ring(handle)!
        return LineString(handle: UnsafeMutableRawPointer(mutating: ptr), ownsHandle: false)
    }

    /// The number of interior rings (holes).
    public var numInteriorRings: Int {
        Int(sfcgal_polygon_num_interior_rings(handle))
    }

    /// Returns the interior ring at zero-based index `i` as a **borrowed** `LineString`.
    ///
    /// - Parameter i: Must be `0 ..< numInteriorRings`.
    public func interiorRingAt(_ i: Int) -> LineString {
        let ptr = sfcgal_polygon_interior_ring_n(handle, i)!
        return LineString(handle: UnsafeMutableRawPointer(mutating: ptr), ownsHandle: false)
    }

    /// Appends a **clone** of `ring` as a new interior hole.
    ///
    /// - Throws: `SFCGALError.operationFailed` if cloning fails.
    public func addInteriorRing(_ ring: LineString) throws {
        guard let cloned = sfcgal_geometry_clone(ring.handle) else {
            throw SFCGALError.operationFailed("Failed to clone interior ring for Polygon")
        }
        sfcgal_polygon_add_interior_ring(handle, cloned)
    }
}

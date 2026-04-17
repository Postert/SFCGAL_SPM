#if canImport(CSFCGAL_System)
import CSFCGAL_System
#elseif canImport(CSFCGAL_Binary)
import CSFCGAL_Binary
#endif
import CSFCGAL_Shim

// MARK: - Type-ID constants

// Mirror of the SFCGAL_TYPE_* C enum values.
// Using raw literals avoids importing sfcgal_geometry_type_id_t directly and
// keeps the Swift side free of cross-platform rawValue casting boilerplate.
private let typePoint              : UInt32 = 1
private let typeLineString         : UInt32 = 2
private let typePolygon            : UInt32 = 3
private let typeMultiPoint         : UInt32 = 4
private let typeMultiLineString    : UInt32 = 5
private let typeMultiPolygon       : UInt32 = 6
private let typeGeometryCollection : UInt32 = 7
private let typePolyhedralSurface  : UInt32 = 15
private let typeTriangulatedSurface: UInt32 = 16
private let typeTriangle           : UInt32 = 17
private let typeSolid              : UInt32 = 101
private let typeMultiSolid         : UInt32 = 102

// MARK: - Factory

/// Returns the most-specific Swift subclass that wraps `handle`.
///
/// This is the single place that maps SFCGAL type IDs to Swift class instances.
/// Pass `ownsHandle: true` (default) when the caller is transferring ownership
/// of the pointer to the returned object.  Pass `ownsHandle: false` when the
/// pointer is borrowed from a parent geometry (e.g. an element of a collection).
///
/// - Parameters:
///   - handle: A valid, non-null `sfcgal_geometry_t *`.
///   - ownsHandle: Whether the returned object should free the pointer in `deinit`.
/// - Returns: A `Geometry` subclass instance appropriate for the type ID stored
///            in `handle`.  Falls back to the base `Geometry` class for unknown types.
internal func makeGeometry(handle: UnsafeMutableRawPointer,
                           ownsHandle: Bool = true) -> Geometry {
    let typeID: UInt32 = numericCast(sfcgal_geometry_type_id(handle).rawValue)
    switch typeID {
    case typePoint:
        return Point(handle: handle, ownsHandle: ownsHandle)
    case typeLineString:
        return LineString(handle: handle, ownsHandle: ownsHandle)
    case typePolygon:
        return Polygon(handle: handle, ownsHandle: ownsHandle)
    case typeMultiPoint:
        return MultiPoint(handle: handle, ownsHandle: ownsHandle)
    case typeMultiLineString:
        return MultiLineString(handle: handle, ownsHandle: ownsHandle)
    case typeMultiPolygon:
        return MultiPolygon(handle: handle, ownsHandle: ownsHandle)
    case typeGeometryCollection:
        return GeometryCollection(handle: handle, ownsHandle: ownsHandle)
    case typePolyhedralSurface:
        return PolyhedralSurface(handle: handle, ownsHandle: ownsHandle)
    case typeTriangulatedSurface:
        return TriangulatedSurface(handle: handle, ownsHandle: ownsHandle)
    case typeTriangle:
        return Triangle(handle: handle, ownsHandle: ownsHandle)
    case typeSolid:
        return Solid(handle: handle, ownsHandle: ownsHandle)
    case typeMultiSolid:
        return MultiSolid(handle: handle, ownsHandle: ownsHandle)
    default:
        return Geometry(handle: handle, ownsHandle: ownsHandle)
    }
}

#if canImport(CSFCGAL_System)
import CSFCGAL_System
#elseif canImport(CSFCGAL_Binary)
import CSFCGAL_Binary
#endif
import CSFCGAL_Shim

// MARK: - GeometryCollection

/// A heterogeneous collection of geometry objects.
///
/// Maps to SFCGAL's `GEOMETRYCOLLECTION` type (type ID 7). Concrete typed
/// sub-collections (`MultiPoint`, `MultiLineString`, `MultiPolygon`,
/// `MultiSolid`) all inherit from this class and share the same access API.
public class GeometryCollection: Geometry {

    // MARK: - Initialisers

    /// Creates an empty geometry collection. Add members with `addGeometry(_:)`.
    ///
    /// - Throws: `SFCGALError.operationFailed` if the C allocation fails.
    public convenience init() throws {
        guard let ptr = try sfcgalCall({ sfcgal_geometry_collection_create() }) else {
            throw SFCGALError.operationFailed("Failed to create empty GeometryCollection")
        }
        self.init(handle: ptr)
    }

    // MARK: - Member access

    /// The number of geometries in this collection.
    public var numGeometries: Int {
        // sfcgal_geometry_collection_num_geometries is deprecated in SFCGAL 2.2;
        // the replacement is sfcgal_geometry_num_geometries.
        Int(sfcgal_geometry_num_geometries(handle))
    }

    /// Returns the geometry at zero-based index `i` as a **borrowed** `Geometry`.
    ///
    /// The returned object is valid only while this collection is alive.
    /// Use `geometryAt(_:) as? ConcreteType` to downcast.
    ///
    /// - Parameter i: Must be `0 ..< numGeometries`.
    public func geometryAt(_ i: Int) -> Geometry {
        // sfcgal_geometry_collection_geometry_n returns const sfcgal_geometry_t *,
        // which Swift imports as UnsafeRawPointer.  Cast to mutable for our init.
        let ptr = sfcgal_geometry_collection_geometry_n(handle, i)!
        return makeGeometry(handle: UnsafeMutableRawPointer(mutating: ptr), ownsHandle: false)
    }

    /// Appends a **clone** of `geometry` to the collection.
    ///
    /// - Throws: `SFCGALError.operationFailed` if cloning fails.
    public func addGeometry(_ geometry: Geometry) throws {
        guard let cloned = sfcgal_geometry_clone(geometry.handle) else {
            throw SFCGALError.operationFailed("Failed to clone geometry for collection insertion")
        }
        sfcgal_geometry_collection_add_geometry(handle, cloned)
    }
}

// MARK: - MultiPoint

/// A collection of `Point` geometries.
///
/// Maps to SFCGAL's `MULTIPOINT` type (type ID 4).
public class MultiPoint: GeometryCollection {

    /// Creates an empty `MultiPoint`.
    ///
    /// - Throws: `SFCGALError.operationFailed` if the C allocation fails.
    public convenience init() throws {
        guard let ptr = try sfcgalCall({ sfcgal_multi_point_create() }) else {
            throw SFCGALError.operationFailed("Failed to create empty MultiPoint")
        }
        self.init(handle: ptr)
    }

    /// Returns the `Point` at zero-based index `i` as a borrowed wrapper.
    public func pointAt(_ i: Int) -> Point {
        let ptr = sfcgal_geometry_collection_geometry_n(handle, i)!
        return Point(handle: UnsafeMutableRawPointer(mutating: ptr), ownsHandle: false)
    }
}

// MARK: - MultiLineString

/// A collection of `LineString` geometries.
///
/// Maps to SFCGAL's `MULTILINESTRING` type (type ID 5).
public class MultiLineString: GeometryCollection {

    /// Creates an empty `MultiLineString`.
    ///
    /// - Throws: `SFCGALError.operationFailed` if the C allocation fails.
    public convenience init() throws {
        guard let ptr = try sfcgalCall({ sfcgal_multi_linestring_create() }) else {
            throw SFCGALError.operationFailed("Failed to create empty MultiLineString")
        }
        self.init(handle: ptr)
    }

    /// Returns the `LineString` at zero-based index `i` as a borrowed wrapper.
    public func lineStringAt(_ i: Int) -> LineString {
        let ptr = sfcgal_geometry_collection_geometry_n(handle, i)!
        return LineString(handle: UnsafeMutableRawPointer(mutating: ptr), ownsHandle: false)
    }
}

// MARK: - MultiPolygon

/// A collection of `Polygon` geometries.
///
/// Maps to SFCGAL's `MULTIPOLYGON` type (type ID 6).
public class MultiPolygon: GeometryCollection {

    /// Creates an empty `MultiPolygon`.
    ///
    /// - Throws: `SFCGALError.operationFailed` if the C allocation fails.
    public convenience init() throws {
        guard let ptr = try sfcgalCall({ sfcgal_multi_polygon_create() }) else {
            throw SFCGALError.operationFailed("Failed to create empty MultiPolygon")
        }
        self.init(handle: ptr)
    }

    /// Returns the `Polygon` at zero-based index `i` as a borrowed wrapper.
    public func polygonAt(_ i: Int) -> Polygon {
        let ptr = sfcgal_geometry_collection_geometry_n(handle, i)!
        return Polygon(handle: UnsafeMutableRawPointer(mutating: ptr), ownsHandle: false)
    }
}

// MARK: - MultiSolid

/// A collection of `Solid` geometries.
///
/// Maps to SFCGAL's `MULTISOLID` type (type ID 102).
public class MultiSolid: GeometryCollection {

    /// Creates an empty `MultiSolid`.
    ///
    /// - Throws: `SFCGALError.operationFailed` if the C allocation fails.
    public convenience init() throws {
        guard let ptr = try sfcgalCall({ sfcgal_multi_solid_create() }) else {
            throw SFCGALError.operationFailed("Failed to create empty MultiSolid")
        }
        self.init(handle: ptr)
    }
}

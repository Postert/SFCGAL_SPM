#if canImport(CSFCGAL_System)
import CSFCGAL_System
#elseif canImport(CSFCGAL_Binary)
import CSFCGAL_Binary
#endif
import CSFCGAL_Shim

/// A surface composed of planar polygon patches sharing edges.
///
/// Maps to SFCGAL's `POLYHEDRALSURFACE` type (type ID 15). Polyhedral surfaces
/// are used to represent building shells in CityGML / IFC data. Each patch is a
/// `Polygon` — typically a planar face of a 3D solid.
public class PolyhedralSurface: Geometry {

    // MARK: - Initialisers

    /// Creates an empty polyhedral surface. Add faces with `addPatch(_:)`.
    ///
    /// - Throws: `SFCGALError.operationFailed` if the C allocation fails.
    public convenience init() throws {
        guard let ptr = try sfcgalCall({ sfcgal_polyhedral_surface_create() }) else {
            throw SFCGALError.operationFailed("Failed to create empty PolyhedralSurface")
        }
        self.init(handle: ptr)
    }

    // MARK: - Patch access

    /// The number of polygon patches that make up this surface.
    public var numPatches: Int {
        Int(sfcgal_polyhedral_surface_num_patches(handle))
    }

    /// Returns the patch (polygon face) at zero-based index `i` as a **borrowed** `Polygon`.
    ///
    /// The returned polygon is valid only while this surface is alive.
    ///
    /// - Parameter i: Must be `0 ..< numPatches`.
    public func patchAt(_ i: Int) -> Polygon {
        let ptr = sfcgal_polyhedral_surface_patch_n(handle, i)!
        return Polygon(handle: UnsafeMutableRawPointer(mutating: ptr), ownsHandle: false)
    }

    /// Appends a **clone** of `polygon` as a new patch.
    ///
    /// - Throws: `SFCGALError.operationFailed` if cloning fails.
    public func addPatch(_ polygon: Polygon) throws {
        guard let cloned = sfcgal_geometry_clone(polygon.handle) else {
            throw SFCGALError.operationFailed("Failed to clone polygon for PolyhedralSurface patch")
        }
        sfcgal_polyhedral_surface_add_patch(handle, cloned)
    }
}

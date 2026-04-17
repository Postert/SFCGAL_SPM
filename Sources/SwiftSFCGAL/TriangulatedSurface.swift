#if canImport(CSFCGAL_System)
import CSFCGAL_System
#elseif canImport(CSFCGAL_Binary)
import CSFCGAL_Binary
#endif
import CSFCGAL_Shim

/// A surface composed entirely of triangular patches (a TIN).
///
/// Maps to SFCGAL's `TIN` (Triangulated Irregular Network) type (type ID 16).
/// TINs are the natural output of SFCGAL's tesselation operations and are
/// efficient for rendering and volume computation.
public class TriangulatedSurface: Geometry {

    // MARK: - Initialisers

    /// Creates an empty TIN. Add triangles with `addPatch(_:)`.
    ///
    /// - Throws: `SFCGALError.operationFailed` if the C allocation fails.
    public convenience init() throws {
        guard let ptr = try sfcgalCall({ sfcgal_triangulated_surface_create() }) else {
            throw SFCGALError.operationFailed("Failed to create empty TriangulatedSurface")
        }
        self.init(handle: ptr)
    }

    // MARK: - Patch access

    /// The number of triangular patches in this TIN.
    public var numPatches: Int {
        Int(sfcgal_triangulated_surface_num_patches(handle))
    }

    /// Returns the triangle at zero-based index `i` as a **borrowed** `Triangle`.
    ///
    /// The returned triangle is valid only while this surface is alive.
    ///
    /// - Parameter i: Must be `0 ..< numPatches`.
    public func patchAt(_ i: Int) -> Triangle {
        let ptr = sfcgal_triangulated_surface_patch_n(handle, i)!
        return Triangle(handle: UnsafeMutableRawPointer(mutating: ptr), ownsHandle: false)
    }

    /// Appends a **clone** of `triangle` as a new patch.
    ///
    /// - Throws: `SFCGALError.operationFailed` if cloning fails.
    public func addPatch(_ triangle: Triangle) throws {
        guard let cloned = sfcgal_geometry_clone(triangle.handle) else {
            throw SFCGALError.operationFailed("Failed to clone triangle for TriangulatedSurface patch")
        }
        sfcgal_triangulated_surface_add_patch(handle, cloned)
    }
}

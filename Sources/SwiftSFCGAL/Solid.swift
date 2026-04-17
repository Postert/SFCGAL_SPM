#if canImport(CSFCGAL_System)
import CSFCGAL_System
#elseif canImport(CSFCGAL_Binary)
import CSFCGAL_Binary
#endif
import CSFCGAL_Shim

/// A 3D volumetric solid with one exterior shell and zero or more interior shells (voids).
///
/// Maps to SFCGAL's `SOLID` type (type ID 101). Each shell is a
/// `PolyhedralSurface`. The exterior shell is shell index 0. Interior shells
/// (voids / holes in the volume) are at indices 1…numShells-1.
///
/// Solids are used for IFC / CityGML LOD3 building models and for SFCGAL's
/// 3D Boolean operations (union, difference, intersection).
public class Solid: Geometry {

    // MARK: - Initialisers

    /// Creates an empty solid. Prefer `init(exteriorShell:)` for the common case.
    ///
    /// - Throws: `SFCGALError.operationFailed` if the C allocation fails.
    public convenience init() throws {
        guard let ptr = try sfcgalCall({ sfcgal_solid_create() }) else {
            throw SFCGALError.operationFailed("Failed to create empty Solid")
        }
        self.init(handle: ptr)
    }

    /// Creates a solid from an exterior `PolyhedralSurface` shell.
    ///
    /// SFCGAL takes ownership of a **clone** of `shell`; the original is unaffected.
    ///
    /// - Parameter shell: The exterior shell (closed polyhedral surface).
    /// - Throws: `SFCGALError.operationFailed` if cloning or allocation fails.
    public convenience init(exteriorShell shell: PolyhedralSurface) throws {
        guard let cloned = sfcgal_geometry_clone(shell.handle) else {
            throw SFCGALError.operationFailed("Failed to clone exterior shell for Solid")
        }
        guard let ptr = try sfcgalCall({ sfcgal_solid_create_from_exterior_shell(cloned) }) else {
            sfcgal_geometry_delete(cloned)
            throw SFCGALError.operationFailed("Failed to create Solid from exterior shell")
        }
        self.init(handle: ptr)
    }

    // MARK: - Shell access

    /// The total number of shells (exterior + interior voids).
    public var numShells: Int {
        Int(sfcgal_solid_num_shells(handle))
    }

    /// Returns the shell at zero-based index `i` as a **borrowed** `PolyhedralSurface`.
    ///
    /// Index 0 is the exterior shell. Higher indices are interior voids.
    /// The returned surface is valid only while this `Solid` is alive.
    ///
    /// - Parameter i: Must be `0 ..< numShells`.
    public func shellAt(_ i: Int) -> PolyhedralSurface {
        let ptr = sfcgal_solid_shell_n(handle, i)!
        return PolyhedralSurface(handle: UnsafeMutableRawPointer(mutating: ptr), ownsHandle: false)
    }

    /// The exterior shell (shorthand for `shellAt(0)`).
    public var exteriorShell: PolyhedralSurface { shellAt(0) }

    /// Appends a **clone** of `shell` as a new interior void.
    ///
    /// - Throws: `SFCGALError.operationFailed` if cloning fails.
    public func addInteriorShell(_ shell: PolyhedralSurface) throws {
        guard let cloned = sfcgal_geometry_clone(shell.handle) else {
            throw SFCGALError.operationFailed("Failed to clone shell for Solid interior void")
        }
        sfcgal_solid_add_interior_shell(handle, cloned)
    }
}

#if canImport(CSFCGAL_System)
import CSFCGAL_System
#elseif canImport(CSFCGAL_Binary)
import CSFCGAL_Binary
#endif
import CSFCGAL_Shim

/// A 2D or 3D point geometry.
///
/// Maps to SFCGAL's `POINT` type (type ID 1). Coordinates are stored as
/// IEEE 754 doubles. The Z coordinate is `Double.nan` for 2D points —
/// check `is3D` before reading `z`.
public class Point: Geometry {

    // MARK: - Initialisers

    /// Creates a 2D point.
    ///
    /// - Parameters:
    ///   - x: X coordinate (longitude / easting).
    ///   - y: Y coordinate (latitude / northing).
    /// - Throws: `SFCGALError.operationFailed` if the C allocation fails.
    public convenience init(x: Double, y: Double) throws {
        guard let ptr = try sfcgalCall({ sfcgal_point_create_from_xy(x, y) }) else {
            throw SFCGALError.operationFailed("Failed to create 2D Point(\(x), \(y))")
        }
        self.init(handle: ptr)
    }

    /// Creates a 3D point.
    ///
    /// - Parameters:
    ///   - x: X coordinate.
    ///   - y: Y coordinate.
    ///   - z: Z coordinate (elevation / depth).
    /// - Throws: `SFCGALError.operationFailed` if the C allocation fails.
    public convenience init(x: Double, y: Double, z: Double) throws {
        guard let ptr = try sfcgalCall({ sfcgal_point_create_from_xyz(x, y, z) }) else {
            throw SFCGALError.operationFailed("Failed to create 3D Point(\(x), \(y), \(z))")
        }
        self.init(handle: ptr)
    }

    // MARK: - Coordinates

    /// X coordinate.
    public var x: Double { sfcgal_point_x(handle) }

    /// Y coordinate.
    public var y: Double { sfcgal_point_y(handle) }

    /// Z coordinate. Returns `Double.nan` for 2D points — always check `is3D` first.
    public var z: Double { sfcgal_point_z(handle) }

    // MARK: - Dimensionality

    /// `true` if this point has a Z coordinate.
    public var is3D: Bool { sfcgal_geometry_is_3d(handle) != 0 }
}

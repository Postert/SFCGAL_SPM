#if canImport(CSFCGAL_System)
import CSFCGAL_System
#elseif canImport(CSFCGAL_Binary)
import CSFCGAL_Binary
#endif
import CSFCGAL_Shim

/// An ordered sequence of points forming a line.
///
/// Maps to SFCGAL's `LINESTRING` type (type ID 2). Points are stored in
/// insertion order. A valid linestring has at least two points.
public class LineString: Geometry {

    // MARK: - Initialisers

    /// Creates an empty linestring. Add points with `addPoint(_:)`.
    ///
    /// - Throws: `SFCGALError.operationFailed` if the C allocation fails.
    public convenience init() throws {
        guard let ptr = try sfcgalCall({ sfcgal_linestring_create() }) else {
            throw SFCGALError.operationFailed("Failed to create empty LineString")
        }
        self.init(handle: ptr)
    }

    // MARK: - Point access

    /// The number of points in this linestring.
    public var numPoints: Int {
        Int(sfcgal_linestring_num_points(handle))
    }

    /// Returns the point at position `i` as a **borrowed** (non-owning) `Point`.
    ///
    /// The returned `Point` is valid only while this `LineString` is alive —
    /// do not store it beyond the linestring's lifetime.
    ///
    /// - Parameter i: Zero-based index. Must be `0 ..< numPoints`.
    /// - Returns: A non-owning `Point` wrapper.
    public func pointAt(_ i: Int) -> Point {
        let ptr = sfcgal_linestring_point_n(handle, i)!
        return Point(handle: UnsafeMutableRawPointer(mutating: ptr), ownsHandle: false)
    }

    /// Appends a **copy** of `point` to the end of this linestring.
    ///
    /// SFCGAL takes ownership of the cloned pointer; the original `point` is
    /// unaffected.
    ///
    /// - Parameter point: The point to append.
    /// - Throws: `SFCGALError.operationFailed` if cloning fails.
    public func addPoint(_ point: Point) throws {
        guard let cloned = sfcgal_geometry_clone(point.handle) else {
            throw SFCGALError.operationFailed("Failed to clone point for LineString insertion")
        }
        sfcgal_linestring_add_point(handle, cloned)
    }

    // MARK: - Sequence convenience

    /// All points as an array of owning `Point` instances (each is a clone).
    ///
    /// - Throws: `SFCGALError.operationFailed` if any clone fails.
    public func points() throws -> [Point] {
        try (0 ..< numPoints).map { i in
            let borrowed = pointAt(i)
            guard let clonedPtr = sfcgal_geometry_clone(borrowed.handle) else {
                throw SFCGALError.operationFailed("Failed to clone point \(i) from LineString")
            }
            return Point(handle: clonedPtr)
        }
    }
}

#if canImport(CSFCGAL_System)
import CSFCGAL_System
#elseif canImport(CSFCGAL_Binary)
import CSFCGAL_Binary
#endif
import CSFCGAL_Shim

/// A triangle defined by exactly three vertices.
///
/// Maps to SFCGAL's `TRIANGLE` type (type ID 17). Triangles are the primitive
/// output of tesselation and TIN (Triangulated Irregular Network) operations.
public class Triangle: Geometry {

    // MARK: - Initialisers

    /// Creates a default (degenerate) triangle. Prefer `init(a:b:c:)`.
    ///
    /// - Throws: `SFCGALError.operationFailed` if the C allocation fails.
    public convenience init() throws {
        guard let ptr = try sfcgalCall({ sfcgal_triangle_create() }) else {
            throw SFCGALError.operationFailed("Failed to create empty Triangle")
        }
        self.init(handle: ptr)
    }

    /// Creates a triangle from three `Point` vertices.
    ///
    /// SFCGAL copies the vertex data; the original points are unaffected.
    ///
    /// - Parameters:
    ///   - a: First vertex.
    ///   - b: Second vertex.
    ///   - c: Third vertex.
    /// - Throws: `SFCGALError.operationFailed` if the C allocation fails.
    public convenience init(a: Point, b: Point, c: Point) throws {
        guard let ptr = try sfcgalCall({
            sfcgal_triangle_create_from_points(a.handle, b.handle, c.handle)
        }) else {
            throw SFCGALError.operationFailed("Failed to create Triangle from points")
        }
        self.init(handle: ptr)
    }

    // MARK: - Vertex access

    /// Returns vertex `i` (0, 1, or 2) as a **borrowed** (non-owning) `Point`.
    ///
    /// The returned point is valid only while this `Triangle` is alive.
    ///
    /// - Parameter i: Must be 0, 1, or 2.
    public func vertex(_ i: Int) -> Point {
        let ptr = sfcgal_triangle_vertex(handle, Int32(i))!
        return Point(handle: UnsafeMutableRawPointer(mutating: ptr), ownsHandle: false)
    }

    /// Shorthand for `vertex(0)`.
    public var vertexA: Point { vertex(0) }

    /// Shorthand for `vertex(1)`.
    public var vertexB: Point { vertex(1) }

    /// Shorthand for `vertex(2)`.
    public var vertexC: Point { vertex(2) }
}

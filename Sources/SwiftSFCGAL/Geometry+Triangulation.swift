#if canImport(CSFCGAL_System)
import CSFCGAL_System
#elseif canImport(CSFCGAL_Binary)
import CSFCGAL_Binary
#endif
import CSFCGAL_Shim

// MARK: - Triangulation operations

extension Geometry {

    // ── Tesselation ───────────────────────────────────────────────────────────

    /// Tesselates this geometry into triangles.
    ///
    /// Returns a `TriangulatedSurface` (the typical result for polygon inputs)
    /// or a `GeometryCollection` of `Triangle` objects, depending on SFCGAL's
    /// internal algorithm for the given geometry type.
    ///
    /// SFCGAL handles cases that simpler triangulators cannot:
    /// - **Vertical surfaces** (building walls where XY area ≈ 0)
    /// - Degenerate or self-touching geometries
    /// - Full 3D geometry without projecting to XY
    ///
    /// The returned geometry is a new, fully owned object.
    ///
    /// - Throws: `SFCGALError.operationFailed` if tesselation fails.
    public func tesselate() throws -> Geometry {
        guard let ptr = try sfcgalCall({ sfcgal_geometry_tesselate(handle) }) else {
            throw SFCGALError.operationFailed("Tesselation failed")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    /// 2D Delaunay triangulation with Z values preserved.
    ///
    /// Performs triangulation in the XY plane using the Delaunay algorithm
    /// (which maximises the minimum angle, avoiding thin "sliver" triangles),
    /// while preserving the Z coordinate from each vertex of the input geometry.
    ///
    /// Useful for terrain meshes where triangulation logic should operate in
    /// plan view but the output must retain correct elevation values.
    ///
    /// The returned geometry is a new, fully owned object.
    ///
    /// - Throws: `SFCGALError.operationFailed` if triangulation fails.
    public func triangulate2DZ() throws -> Geometry {
        guard let ptr = try sfcgalCall({ sfcgal_geometry_triangulate_2dz(handle) }) else {
            throw SFCGALError.operationFailed("Triangulate 2DZ failed")
        }
        return makeGeometry(handle: ptr, ownsHandle: true)
    }

    // ── Vertex extraction ─────────────────────────────────────────────────────

    /// Extracts triangle vertices as a flat `[Float]` array ready for GPU upload.
    ///
    /// The layout is `[x₀, y₀, z₀,  x₁, y₁, z₁,  x₂, y₂, z₂, …]` —
    /// three `Float` values per vertex, three vertices per triangle, triangles
    /// in SFCGAL order.  The array length is always `numTriangles × 9`.
    ///
    /// 2D vertices (no Z component) contribute `0.0` for their Z channel.
    ///
    /// This output is compatible with RealityKit's `MeshDescriptor.positions`:
    ///
    /// ```swift
    /// let floats = try polygon.triangleVertices()
    /// // floats.count == numTriangles * 9
    /// var desc = MeshDescriptor()
    /// desc.positions = MeshBuffer(
    ///     stride(from: 0, to: floats.count, by: 3).map {
    ///         SIMD3<Float>(floats[$0], floats[$0 + 1], floats[$0 + 2])
    ///     }
    /// )
    /// ```
    ///
    /// - Throws: `SFCGALError.operationFailed` if the underlying tesselation fails.
    /// - Returns: Flat `[Float]` of length `numTriangles × 9`.
    public func triangleVertices() throws -> [Float] {
        let tessellated = try tesselate()
        return Geometry.extractVertices(from: tessellated)
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /// Walks a `TriangulatedSurface` or `GeometryCollection` and collects
    /// `[x, y, z]` float triples for every triangle vertex.
    private static func extractVertices(from geom: Geometry) -> [Float] {
        var vertices: [Float] = []

        if let tin = geom as? TriangulatedSurface {
            // Normal case — tesselate() returns a TriangulatedSurface for polygon inputs.
            vertices.reserveCapacity(tin.numPatches * 9)
            for i in 0..<tin.numPatches {
                appendTriangle(tin.patchAt(i), into: &vertices)
            }
        } else if let col = geom as? GeometryCollection {
            // Fallback — some geometry types produce a GeometryCollection of triangles.
            vertices.reserveCapacity(col.numGeometries * 9)
            for i in 0..<col.numGeometries {
                if let tri = col.geometryAt(i) as? Triangle {
                    appendTriangle(tri, into: &vertices)
                }
            }
        }

        return vertices
    }

    /// Appends the three (x, y, z) float triples of `triangle` to `vertices`.
    /// 2D points (no Z) contribute 0.0 for the Z channel.
    private static func appendTriangle(_ triangle: Triangle, into vertices: inout [Float]) {
        for j in 0..<3 {
            let pt = triangle.vertex(j)
            vertices.append(Float(pt.x))
            vertices.append(Float(pt.y))
            vertices.append(pt.is3D ? Float(pt.z) : 0.0)
        }
    }
}
